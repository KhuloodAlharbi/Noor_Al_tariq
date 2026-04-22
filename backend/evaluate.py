"""
Noor Al-Tareeq — RAG Accuracy Evaluation
Run: python evaluate.py
Requires: pip install ragas datasets anthropic
"""

import os
import json
import pandas as pd
import numpy as np
import joblib
from sentence_transformers import SentenceTransformer
import anthropic
from dotenv import load_dotenv

load_dotenv()

# ---------------------------------------------------------------------------
# Load artifacts (same as app.py)
# ---------------------------------------------------------------------------
print("Loading artifacts...")
df = pd.read_parquet("fatwas_clean.parquet")
embeddings = np.load("fatwa_embeddings.npy")
nn = joblib.load("nn_index.joblib")
encoder = SentenceTransformer("sentence-transformers/all-mpnet-base-v2")
client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
print(f"Loaded {len(df)} fatwas.\n")

# ---------------------------------------------------------------------------
# Helpers (same logic as app.py)
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
            "title": str(row.get("Title", "")),
            "question": str(row.get("Question", "")),
            "answer": str(row.get("Answer", "") or ""),
        })
    return results


def get_answer(question: str, contexts: list[str]) -> str:
    context_text = "\n\n".join(
        f"Fatwa {i+1}: {c}" for i, c in enumerate(contexts)
    )
    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=512,
        system=(
            "You are Noor Al-Tareeq, an Islamic fatwa assistant. "
            "Answer based only on the provided fatwas. "
            "Be concise (2-3 sentences). No markdown. No links."
        ),
        messages=[
            {
                "role": "user",
                "content": f"CONTEXT:\n{context_text}\n\nQUESTION: {question}",
            }
        ],
    )
    return response.content[0].text


# ---------------------------------------------------------------------------
# Test questions with ground truth
# ---------------------------------------------------------------------------
TEST_SET = [
    "I want to get married to a girl whose father is in another country, and at present I cannot travel there for us to meet and do the marriage contract, because of my financial situation and other reasons. I am living in a foreign country. Is it permissible for me to call her father on the phone so that he can say to me, 'I marry my daughter so and so to you,' and I can say, 'I accept,' with the girl's consent and with two Muslim witnesses listening to what is said by means of loudspeakers attached to the phone? Would this be considered a valid marriage contract in shari'ah?",
    "Is it better to recite from the Mushaf than from memory? Please explain.",
    "What is the ruling on reading Quran collectively in the mosque?",
    "If the alcohol in which perfume is dissolved is of a type that is poisonous, not intoxicating, is it permissible to use this perfume?",
    "One of the mosques has announced that there will be iftaar for anyone who wants to fast on Thursdays. What is the ruling on this?",
    "Which takes priority, doing the obligatory (first) Hajj, or paying off one's father's debt?",
    "What is the ruling on gathering to recite du'a for completing the Quran, when a person completes reading the Quran and invites the rest of his family and others to come and recite the du'a together?",
    "I have become Muslim, al-hamdu-Lillaah, but I do not know Arabic. What should I do with regard to the adhkar in the prayer and reading Quran in Arabic?",
    "What is the ruling on crossword puzzles and doing them?",
    "What is the ruling on so-called test-tube babies?",
    "If something happens to the imam (he breaks his wudoo'), is it permissible for one of the members of the congregation to take over and lead the others in prayer?",
    "What are the virtues of a man reciting ruqyah for himself? What is the evidence for that?",
    "A woman has been given the choice by her husband of either going with him when he goes to study in a kaafir country, or staying in the Muslim country. Should she go with him or not?",
    "What is the ruling on working as a doctor in the army of the kuffaar who are not in a state of war with the Muslims?",
    "What is the ruling on the imaam of the mosque giving an announcement every time someone in the neighbourhood passes away?",
    "Can a person go for Hajj without his parents' permission, and will his Hajj be valid?",
    "Eating bread, watermelon, fruits etc., in the mosque – is this permitted or should it not be allowed?",
    "If a dhimmi woman dies when she is pregnant with a Muslim child, where should she be buried?",
    "What is the ruling on purifying oneself with Zamzam water?",
    "If a Muslim sneezes and does not say 'Al-hamdu Lillaah', does he deserve to have others say 'Yarhamuk Allah' to him?",
    "What is the ruling on kissing another person's hand?",
    "What is the ruling on one who plants something, then he dies and the plants go to his heir? Who gets the reward?",
    "What is the ruling on jalsah al-istiraahah?",
    "A graveyard had been endowed for the burial of Muslims, and someone built a mosque with a mihrab in it. Is this permissible?",
    "What is the ruling on dyeing a white beard?",
    "If a member of the congregation is not sure whether the place where he was standing was in front of the imaam or not, what is the ruling?",
    "A man is extremely sick and cannot stand or sit, or remove impurity. Does he still have to pray?",
    "If a person was disobedient towards his parents, and they died angry with him, how can he put things right?",
    "If a person thinks that if he greets someone, that person will most likely not return his salaam, should he still say salaam or not?",
]

# ---------------------------------------------------------------------------
# Run evaluation
# ---------------------------------------------------------------------------
print("Running evaluation on", len(TEST_SET), "questions...\n")

questions = []
answers   = []
contexts  = []

for i, q in enumerate(TEST_SET):
    print(f"[{i+1}/{len(TEST_SET)}] {q[:90]}")

    retrieved = search_fatwas(q, top_k=3)
    ctx = [r["answer"][:400] for r in retrieved]
    ans = get_answer(q, ctx)

    questions.append(q)
    answers.append(ans)
    contexts.append(ctx)

    print(f"  → {ans[:120]}...\n")

# ---------------------------------------------------------------------------
# LLM-as-Judge scoring (Claude evaluates its own answers)
# ---------------------------------------------------------------------------
print("\nCalculating scores using LLM-as-Judge...")

def judge(question, answer, ctx_list):
    context_text = "\n".join(f"Fatwa {i+1}: {c[:300]}" for i, c in enumerate(ctx_list))
    prompt = f"""You are an objective evaluator for an Islamic fatwa RAG system.
Score the following on a scale of 0.0 to 1.0 for each metric.

Question: {question}
Retrieved Fatwas: {context_text}
System Answer: {answer}

Definitions:
- context_precision: Are the retrieved fatwas relevant to the question? (0=irrelevant, 1=perfectly relevant)
- faithfulness: Does the answer stay true to the fatwas without adding unsupported claims? (0=hallucinated, 1=fully grounded)
- answer_relevancy: Does the answer directly address the question asked? (0=off-topic, 1=fully addresses it)

Respond ONLY with valid JSON, nothing else:
{{"context_precision": 0.0, "faithfulness": 0.0, "answer_relevancy": 0.0}}"""

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=60,
        messages=[{"role": "user", "content": prompt}],
    )
    return json.loads(response.content[0].text.strip())


all_scores = {"context_precision": [], "faithfulness": [], "answer_relevancy": []}

for i, (q, a, ctx) in enumerate(zip(questions, answers, contexts)):
    print(f"  Scoring [{i+1}/{len(questions)}] {q[:60]}...")
    try:
        s = judge(q, a, ctx)
        for k in all_scores:
            all_scores[k].append(float(s.get(k, 0)))
    except Exception as e:
        print(f"    Warning: scoring failed — {e}")
        for k in all_scores:
            all_scores[k].append(0.0)

scores = {
    "Context Precision": round(sum(all_scores["context_precision"]) / len(questions), 4),
    "Faithfulness":      round(sum(all_scores["faithfulness"])      / len(questions), 4),
    "Answer Relevancy":  round(sum(all_scores["answer_relevancy"])  / len(questions), 4),
}

print("\n" + "=" * 50)
print(f"  EVALUATION RESULTS  (LLM-as-Judge, n={len(questions)})")
print("=" * 50)
for metric, score in scores.items():
    bar = "█" * int(score * 20)
    print(f"  {metric:<22} {score:.4f}  {bar}")
print("=" * 50)

with open("evaluation_results.json", "w") as f:
    json.dump({"scores": scores, "n_questions": len(TEST_SET),
               "method": "LLM-as-Judge (Claude)"}, f, indent=2)
print("\nResults saved to evaluation_results.json")
