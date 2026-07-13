extends Node

var api_manager: APIManager = null
var error_log: Array = []

func _ready():
    api_manager = get_node_or_null("/root/APIManager")
    if api_manager == null:
        print("APIManager não encontrado. O diagnóstico IA não funcionará.")

func add_error(error_message: String):
    error_log.append({"time": Time.get_datetime_string_from_system(), "error": error_message})
    if error_log.size() > 50:
        error_log.pop_front()

func get_diagnostic() -> String:
    if error_log.is_empty():
        return "Nenhum erro registrado nesta sessão."
    
    var report = "Relatório de Erros:\n"
    for entry in error_log:
        report += "[" + entry.time + "] " + entry.error + "\n"
    return report

func ask_ai_for_fix(error_message: String) -> String:
    if api_manager == null:
        return "Serviço de IA não disponível (APIManager ausente)."
    
    var api_key = api_manager.get_key("openai")
    if api_key == "":
        return "Chave da API OpenAI não configurada. Adicione em api_config.json."
    
    var http = HTTPRequest.new()
    add_child(http)
    http.request_completed.connect(_on_ai_response)
    
    var body = JSON.stringify({
        "model": "gpt-4o-mini",
        "messages": [
            {"role": "system", "content": "Você é um assistente de diagnóstico para o jogo EmpireCraft Tycoon. Analise o erro e sugira uma correção simples e direta em português."},
            {"role": "user", "content": "Erro reportado: " + error_message}
        ],
        "temperature": 0.3
    })
    
    var headers = [
        "Content-Type: application/json",
        "Authorization: Bearer " + api_key
    ]
    
    var err = http.request("https://api.openai.com/v1/chat/completions", headers, HTTPClient.METHOD_POST, body)
    if err != OK:
        return "Falha na comunicação com a API de IA."
    
    return "Consultando IA..."

func _on_ai_response(result, response_code, headers, body):
    var json = JSON.parse_string(body.get_string_from_utf8())
    if json and json.has("choices"):
        var reply = json.choices[0].message.content
        var support_screen = get_node_or_null("/root/SupportScreen")
        if support_screen:
            support_screen.show_ai_reply(reply)
    else:
        var support_screen = get_node_or_null("/root/SupportScreen")
        if support_screen:
            support_screen.show_ai_reply("A IA não conseguiu analisar o erro.")
