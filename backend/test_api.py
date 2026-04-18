import requests

BASE_URL = "http://127.0.0.1:8000"

def test_chat(question: str):
    url = f"{BASE_URL}/chat"
    resp = requests.post(url, json={"question": question})

    print("Status code:", resp.status_code)
    print("Raw response:", resp.text)

    try:
        data = resp.json()
        print("Parsed JSON:", data)
        print("Answer field:", data.get("answer"))
    except Exception as e:
        print("JSON parse error:", e)

if __name__ == "__main__":
    test_chat("What is the ruling on Hajj?")
