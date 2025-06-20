import openai
import os
from dotenv import load_dotenv

load_dotenv()

def main():
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("[!] Please set the OPENAI_API_KEY environment variable.")
        return

    client = openai.OpenAI(api_key=api_key)

    print("=" * 40)
    print("[*] Explain Like I'm 5 - CLI Edition")
    print("=" * 40)
    print("Paste anything complicated and let AI break it down for you!\n")

    user_input = input("Enter something you want explained: ").strip()
    if not user_input:
        print("[!] You must enter something to explain.")
        return

    prompt = f"""
You're a funny, helpful assistant that explains things in the simplest, silliest way possible — like you're talking to someone with no background knowledge. Be clear, funny, and very simple, but still informative.
Explain the following like I'm completely clueless and 5 years old. avoid jargon, use analogies, and make it fun:
{user_input}
End your response with '#ELI5'
The response must not exceed 280 characters (including spaces, punctuation, and hashtags)
"""

    print("\nThinking like a genius... explaining like you're 5...\n")
    try:
        response = client.chat.completions.create(
            model="gpt-4.1",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=500,
            temperature=0.8
        )
        explanation = response.choices[0].message.content.strip()
        print("=" * 40)
        print("🧾 Your ultra-dumb explanation:")
        print("=" * 40)
        print(explanation)
        print("=" * 40)
    except Exception as e:
        print(f"[!] Something went wrong: {e}")

if __name__ == '__main__':
    main()