import os
import json
import firebase_admin
from firebase_admin import credentials, firestore
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from google import genai
from dotenv import load_dotenv

# 1. Carrega as variáveis de ambiente do arquivo .env
load_dotenv()

# 2. Inicializa o cliente oficial da Gemini API
api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    raise RuntimeError("A variável GEMINI_API_KEY não foi encontrada no arquivo .env.")

gemini_client = genai.Client(api_key=api_key)

# 3. Inicialização do Firebase Admin SDK (Compatível com arquivo local ou variável de ambiente na nuvem)
firebase_config_str = os.getenv("FIREBASE_CONFIG_JSON")

if firebase_config_str:
    cred_dict = json.loads(firebase_config_str)
    cred = credentials.Certificate(cred_dict)
else:
    cred = credentials.Certificate("serviceAccountKey.json")

if not firebase_admin._apps:
    firebase_admin.initialize_app(cred)

db = firestore.client(database_id="ia-psicologa")

# 4. Inicialização do aplicativo FastAPI
app = FastAPI(title="API IA Psicóloga")

# Configuração de CORS para permitir requisições da Web / Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Prompt do sistema definindo a persona e diretrizes de segurança
SYSTEM_PROMPT = """
Você é uma assistente virtual de apoio emocional e reflexão baseada em abordagens da Psicologia Humanista e Terapia Cognitivo-Comportamental.
Sua função é oferecer escuta empática, acolhimento e perguntas reflexivas.

REGRAS OBRIGATÓRIAS DE SEGURANÇA:
1. Você NÃO é uma médica ou psicóloga humana licenciada e NÃO pode diagnosticar, prescrever remédios ou emitir laudos.
2. Em caso de ideação suicida, automutilação ou emergência psiquiátrica, interrompa imediatamente a conversa estruturada e forneça a mensagem de emergência solicitando que a pessoa entre em contato com o CVV (188 no Brasil) ou um serviço de emergência local.
3. Seja sempre respeitosa, neutra e evite julgamentos.
"""

# Modelo de requisição recebido pelo endpoint
class ChatRequest(BaseModel):
    message: str

@app.post("/api/chat")
async def chat(request: ChatRequest):
    uid = "usuario_teste"

    try:
        # Recupera as últimas mensagens do Firestore para manter o contexto
        history_text = ""
        try:
            history_ref = (
                db.collection("users")
                .document(uid)
                .collection("messages")
                .order_by("timestamp", direction=firestore.Query.DESCENDING)
                .limit(6)
            )
            docs = list(history_ref.stream())
            docs.reverse()
            for doc in docs:
                d = doc.to_dict()
                history_text += f"{d.get('role')}: {d.get('content')}\n"
        except Exception as e_fs:
            print(f"[AVISO FIRESTORE LEITURA]: {e_fs}")

        # Monta o prompt combinando a persona, histórico e mensagem atual
        full_prompt = (
            f"{SYSTEM_PROMPT}\n\n"
            f"Histórico de conversa:\n{history_text}\n\n"
            f"Usuário: {request.message}\n"
            f"Assistente:"
        )

        # Chamada à API da Gemini atualizada
        response = gemini_client.models.generate_content(
            model="gemini-3.6-flash",
            contents=full_prompt,
        )
        reply = response.text

        # Persiste a conversa de entrada e resposta no Firestore
        try:
            user_messages_ref = db.collection("users").document(uid).collection("messages")
            user_messages_ref.add({
                "role": "user",
                "content": request.message,
                "timestamp": firestore.SERVER_TIMESTAMP
            })
            user_messages_ref.add({
                "role": "assistant",
                "content": reply,
                "timestamp": firestore.SERVER_TIMESTAMP
            })
        except Exception as e_fs_save:
            print(f"[AVISO FIRESTORE ESCRITA]: {e_fs_save}")

        return {"response": reply}

    except Exception as e:
        print(f"\n[ERRO GEMINI API]: {e}\n")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port)