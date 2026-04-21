import os
import pandas as pd
import numpy as np
import joblib
from sentence_transformers import SentenceTransformer
from flask import Flask, request, jsonify
from flask_cors import CORS
import anthropic

app = Flask(__name__)
CORS(app)

# ---------------------------------------------------------------------------
# Load artifacts
# ---------------------------------------------------------------------------
print("Loading artifacts ...")
df = pd.read_parquet("fatwas_clean.parquet")
embeddings = np.load("fatwa_embeddings.npy")
nn = joblib.load("nn_index.joblib")
encoder = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")
print(f"Ready — {len(df)} fatwas loaded.")

client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

SYSTEM_PROMPT = """You are Noor Al-Tareeq, an Islamic fatwa assistant chatbot.

RULES:
1. Only begin your FIRST reply in a new conversation with:
   "Assalamu alaikum, I am Noor Al-Tareeq. How can I help you today?" in the user's language.
2. Never repeat this greeting in subsequent turns.
3. Base your answer on the fatwas provided in CONTEXT.
4. Keep answers short — 2 to 4 sentences maximum. Be direct and clear.
5. Never use markdown: no **, no ##, no ---, no bullet points, no numbered lists.
6. Never include URLs, links, or source references.
7. Maintain a calm, respectful Islamic tone.
8. Respond in the same language the user wrote in."""

# In-memory conversation store keyed by session_id
sessions: dict[str, list[dict]] = {}


# ---------------------------------------------------------------------------
# RAG helpers
# ---------------------------------------------------------------------------
def search_fatwas(query: str, top_k: int = 3) -> list[dict]:
    query_emb = encoder.encode([query], normalize_embeddings=True)
    distances, indices = nn.kneighbors(query_emb, n_neighbors=top_k)
    results = []
    for i, idx in enumerate(indices[0]):
        row = df.iloc[idx]
        results.append({
            "score": float(distances[0][i]),
            "Qno": int(row["Qno"]),
            "title": row["Title"],
            "question": row["Question"],
            "answer": row["Answer"],
            "url": row["URL"],
        })
    return results


def format_context(docs: list[dict], max_chars: int = 400) -> str:
    text = ""
    for d in docs:
        text += (
            f"\nFatwa Q{d['Qno']} — {d['title']}\n"
            f"QUESTION: {d['question']}\n"
            f"ANSWER (truncated): {str(d['answer'] or '')[:max_chars]}\n"
            f"SOURCE: {d['url']}\n"
            "-----------------------------\n"
        )
    return text


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------
@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok", "fatwas": len(df)})


@app.route("/rag", methods=["POST"])
def rag_endpoint():
    user_query = (request.json or {}).get("question", "")
    hits = search_fatwas(user_query, top_k=1)
    if not hits:
        return jsonify({"answer": "No matching fatwa found."})
    return jsonify({"answer": hits[0]["answer"], "source": hits[0]["url"]})


@app.route("/chat", methods=["POST"])
def chat_endpoint():
    data = request.json or {}
    user_query = data.get("question", "").strip()
    session_id = data.get("session_id", "default")

    if not user_query:
        return jsonify({"error": "question is required"}), 400

    history = sessions.setdefault(session_id, [])
    is_first_turn = len(history) == 0

    retrieved = search_fatwas(user_query, top_k=3)
    context_text = format_context(retrieved)

    messages = []
    for turn in history:
        messages.append({"role": "user",      "content": turn["user"]})
        messages.append({"role": "assistant", "content": turn["bot"]})
    messages.append({
        "role": "user",
        "content": f"CONTEXT (Fatwas):\n{context_text}\n\nUSER QUESTION:\n{user_query}",
    })

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        system=SYSTEM_PROMPT,
        messages=messages,
    )
    answer_text = response.content[0].text

    # Prepend greeting on first turn if the model skipped it
    if is_first_turn and "assalamu" not in answer_text[:40].lower() and "السلام" not in answer_text[:40]:
        is_arabic = any("\u0600" <= c <= "\u06ff" for c in user_query)
        greeting = (
            "السلام عليكم، أنا نور الطريق. كيف يمكنني مساعدتك اليوم؟\n\n"
            if is_arabic
            else "Assalamu alaikum, I am Noor Al-Tareeq. How can I help you today?\n\n"
        )
        answer_text = greeting + answer_text

    history.append({"user": user_query, "bot": answer_text})
    return jsonify({"answer": answer_text})


@app.route("/reset", methods=["POST"])
def reset_session():
    session_id = (request.json or {}).get("session_id", "default")
    sessions.pop(session_id, None)
    return jsonify({"status": "reset"})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=False)
