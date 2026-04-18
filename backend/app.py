from flask import Flask, request, jsonify
import pandas as pd
import numpy as np
import joblib
from sentence_transformers import SentenceTransformer
from sklearn.neighbors import NearestNeighbors
import google.generativeai as genai
from flask_cors import CORS
app = Flask(__name__)
CORS(app)


# Load saved model files
df = pd.read_parquet("fatwas_clean.parquet")
embeddings = np.load("fatwa_embeddings.npy")
nn = joblib.load("nn_index.joblib")
from sentence_transformers import SentenceTransformer
model = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")



# Add your Gemini API key here
genai.configure(api_key="AIzaSyBttT-YSs7WfuDkTGzwozmxFdKv4bV-XoM")


def search_fatwas(query, top_k=3):
    query_emb = model.encode([query], normalize_embeddings=True)
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
            "url": row["URL"]
        })
    return results


def format_context(docs):
    text = ""
    for d in docs:
        ans_short = d["answer"][:400]
        text += f"""
Fatwa Q{d['Qno']} — {d['title']}
QUESTION: {d['question']}
ANSWER: {ans_short}
SOURCE: {d['url']}
-----------------------------
"""
    return text


app = Flask(__name__)


@app.route("/rag", methods=["POST"])
def rag_endpoint():
    user_query = request.json.get("question", "")
    hits = search_fatwas(user_query, top_k=1)
    if not hits:
        return jsonify({"answer": "No matching fatwa found."})
    return jsonify({"answer": hits[0]["answer"], "source": hits[0]["url"]})


@app.route("/chat", methods=["POST"])
def chat_endpoint():
    user_query = request.json.get("question")

    retrieved = search_fatwas(user_query, top_k=3)
    context_text = format_context(retrieved)

    prompt = f"""
Using ONLY the provided fatwas, answer the user's question.
Respond in the SAME LANGUAGE as the user.

CONTEXT:
{context_text}

QUESTION:
{user_query}

Answer:
"""
    llm = genai.GenerativeModel("models/gemini-flash-latest")
    out = llm.generate_content(prompt)

    return jsonify({"answer": out.text})


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)
