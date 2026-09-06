from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
import google.generativeai as genai
import os

app = FastAPI()

# 1. Configuração de CORS para permitir requisições do Flutter (Web e Mobile)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Permite requisições de qualquer origem
    allow_credentials=True,
    allow_methods=["*"],  # Permite todos os métodos (POST, GET, etc.)
    allow_headers=["*"],  # Permite todos os headers (incluindo o token)
)

# 2. Configuração da chave da API do Gemini 
# (Certifique-se de configurar a variável de ambiente GEMINI_API_KEY no painel do Render)
# genai.configure(api_key=os.environ.get("GEMINI_API_KEY"))

@app.get("/")
def read_root():
    return {"status": "API da Psicóloga IA rodando com sucesso!"}

@app.post("/api/chat")
async def chat_endpoint(request: Request):
    try:
        # Lê o corpo da requisição enviado pelo Flutter
        body = await request.json()
        user_message = body.get("message", "")
        
        if not user_message:
            return {"response": "Por favor, digite uma mensagem válida."}

        # Configura o modelo do Gemini
        model = genai.GenerativeModel("gemini-1.5-flash")
        
        # Tenta gerar a resposta da IA
        chat_response = model.generate_content(user_message)
        ai_reply = chat_response.text

        # Retorna a resposta com sucesso para o Flutter
        return {"response": ai_reply}

    except Exception as e:
        # Exibe o erro real no console do Render para você conseguir debugar
        print(f"Erro detalhado no servidor: {str(e)}")
        
        # Retorna uma mensagem amigável para o app Flutter (evitando o erro 500)
        return {
            "response": "Desculpe, ocorreu um pequeno imprevisto ao processar sua mensagem ou o assunto pode ter ativado meus filtros de segurança. Poderia reformular ou tentar falar sobre outro ponto?"
        }