# Variáveis globais para acumulação offline
var offline_acc1 = 0
var offline_acc2 = 0
var offline_acc3 = 0
var offline_acc4 = 0
var offline_acc5 = 0
var connection_failed = false

# Função para atualizar os acumuladores
def update_accumulators()
    # 0. Ler o estado dos POWERs
    var power = tasmota.get_power()
    var sensors = json.load(tasmota.read_sensors())
    var s2 = sensors["Switch2"]
    var s3 = sensors["Switch3"]
    
    if power[0] || (s2 == "OFF") || power[2] || power[3] || (s3 == "OFF")
        # 1. Tentar ler os valores acumulados atuais do canal de leitura
        var client = webclient()
        var url_read = "https://api.thingspeak.com/channels/2881363/feeds.json?api_key=YA4SPF6193RQCBVK&results=1"
        var response = nil
        var s = ""
        
        try
            response = client.begin(url_read)
            var r = client.GET()
            s = client.get_string()
        except .. as e
            print("Exception ao tentar conexão: " + str(e))
            response = nil
        end
        
        if response == nil
            # Se falhar a conexão, acumular localmente
            print("Erro ao conectar. Acumulando localmente...")
            connection_failed = true
            
            if power[0] offline_acc1 += 1 end
            if s2 == "OFF" offline_acc2 += 1 end
            if power[2] offline_acc3 += 1 end
            if power[3] offline_acc4 += 1 end
            if s3 == "OFF" offline_acc5 += 1 end
            
            return
        end
        
        # Se chegou aqui, a conexão foi bem sucedida
        var feed = json.load(s)
        var acc1 = int(feed["feeds"][0]["field1"])
        var acc2 = int(feed["feeds"][0]["field2"])
        var acc3 = int(feed["feeds"][0]["field3"])
        var acc4 = int(feed["feeds"][0]["field4"])
        var acc5 = int(feed["feeds"][0]["field5"])
        
        # Se houve falha anterior e temos valores acumulados localmente
        if connection_failed && (offline_acc1 > 0 || offline_acc2 > 0 || offline_acc3 > 0 || offline_acc4 > 0 || offline_acc5 > 0)
            print("Conexão restabelecida. Enviando dados acumulados...")
            acc1 += offline_acc1
            acc2 += offline_acc2
            acc3 += offline_acc3
            acc4 += offline_acc4
            acc5 += offline_acc5
            
            # Resetar acumuladores locais
            offline_acc1 = 0
            offline_acc2 = 0
            offline_acc3 = 0
            offline_acc4 = 0
            offline_acc5 = 0
            connection_failed = false
        end
        
        if power[0] acc1 += 1 end
        if s2 == "OFF" acc2 += 1 end
        if power[2] acc3 += 1 end
        if power[3] acc4 += 1 end
        if s3 == "OFF" acc5 += 1 end
        
        # 3. Atualizar os acumuladores no canal de update
        var url_update = "https://api.thingspeak.com/update?api_key=Q1YK1HIDIEMHH07E" +
                         "&field1=" + str(acc1) +
                         "&field2=" + str(acc2) +
                         "&field3=" + str(acc3) +
                         "&field4=" + str(acc4) +
                         "&field5=" + str(acc5)
        
        try
            print(url_update)
            response = client.begin(url_update)
            var r = client.GET()
            var s_update = client.get_string()
            
            if response != nil
                print("Acc atual.: " + s_update)
            else
                print("Erro ao atualizar os acumuladores.")
                # Se falhar no envio, manter os valores acumulados
                connection_failed = true
                if power[0] offline_acc1 += 1 end
                if s2 == "OFF" offline_acc2 += 1 end
                if power[2] offline_acc3 += 1 end
                if power[3] offline_acc4 += 1 end
                if s3 == "OFF" offline_acc5 += 1 end
            end
        except .. as e
            print("Exception ao tentar atualizar: " + str(e))
            connection_failed = true
            if power[0] offline_acc1 += 1 end
            if s2 == "OFF" offline_acc2 += 1 end
            if power[2] offline_acc3 += 1 end
            if power[3] offline_acc4 += 1 end
            if s3 == "OFF" offline_acc5 += 1 end
        end
    end
end
