import json
import string

tasmota.cmd("TimeZone -3")  #fuso horário para UTC-3 (braZil)
tasmota.cmd("SwitchMode1 16")
tasmota.cmd("SwitchMode2 16")
tasmota.cmd("SwitchMode3 16")
tasmota.cmd("SwitchMode4 16")

# Variável global para armazenar os eventos programados
var programa = nil

# Função para enviar dados
def send_to_thingspeak()
    var sensors = json.load(tasmota.read_sensors())
    var t1 = sensors["DHT11-19"]["Temperature"]
    var t2 = sensors["DHT11-23"]["Temperature"]
    var t3 = sensors["Switch1"]
    var t4 = sensors["Switch2"]
    var t5 = sensors["Switch3"]
    var t6 = sensors["Switch4"]
    var t7 = tasmota.get_power()
    var t8 = sensors["DHT11-19"]["Humidity"]
    
    # Converte a lista sem espaços
    var t7_str = "[" + str(t7[0]) + "," + str(t7[1]) + "," + str(t7[2]) + "," + str(t7[3]) + "]"
    
    # Verifica se t1 ou t2 são nil
    if t1 == nil || t2 == nil
        tasmota.cmd("Buzzer <beep>")  # Emite um bip no buzzer
        print("t1 ou t2 é nil. Bip no buzzer emitido.")
    end

    var api_key = "I74K99ICGPWDV6U3"
    var urlT = "http://api.thingspeak.com/update?api_key=" + api_key + "&field1=" + str(t1) + "&field2=" + str(t2) + "&field3=" + str(t3) + "&field4=" + str(t4) + "&field5=" + str(t5) + "&field6=" + str(t6) + "&field7=" + t7_str + "&field8=" + str(t8)
    print(urlT)
    var client = webclient()
    var response = client.begin(urlT)
    var r = client.GET()
    var s = client.get_string()
    if response != nil
        print("Enviado. Resposta:", s)
    else
        print("Erro ao enviar dados")
    end

    # Verifica programação de acionamentos
    response = client.begin("http://api.thingspeak.com/channels/2881334/feeds.json?api_key=A20FA0PNZ71I3IIJ&results=1")
    r = client.GET()
    s = client.get_string()
    if response != nil
        programa = json.load(s)["feeds"]
    else
        print("Erro ao receber dados. Mantendo os eventos atuais.")
    end
end

def process_events(pump_index)
    if programa != nil && size(programa) > 0
        var event_data_str = programa[0]["field" + str(pump_index)]
        if event_data_str != nil && event_data_str != ""
            print("Eventos " + str(pump_index) + ": " + event_data_str)

            var event_list = string.split(event_data_str, ";")

            for i : 0 .. size(event_list) - 1
                var event_data = event_list[i]
                if event_data != ""
                    var event_parts = string.split(event_data, ",")
                    if size(event_parts) == 5
                        var day = event_parts[0]
                        var start_times = event_parts[1]
                        var S_time_parts = string.split(start_times, ":")
			var S_start_times = S_time_parts[0]+S_time_parts[1]
			var start_time = int(S_start_times)
                        var end_times = event_parts[2]
                     	var S_end_parts = string.split(end_times, ":")
			var S_end_times = S_end_parts[0]+S_end_parts[1]
			var end_time = int(S_end_times)
                        var temperature = int(event_parts[3])
                        var S_power = int(event_parts[4])

                        var now = tasmota.cmd("Time")["Time"]
                        var date_time_parts = string.split(now, "T")
			var date_part = date_time_parts[0]  # "2025-03-18"
			var time_part = date_time_parts[1]  # "11:05:33"
			var time_parts = string.split(time_part, ":")
			var current_time = int(str(time_parts[0]) + str(time_parts[1])) # 1105
			var date_parts = string.split(date_part, "-")
			var year = int(date_parts[0])  # "2025"
			var month = int(date_parts[1])  # "03"
			var dday = int(date_parts[2])   # "18"

                        if month < 3
                            month = month + 12
                            year = year - 1
                        end
                        var k = year % 100
                        var j = year / 100
                        var weekday_num = (dday + ((13 * (month + 1)) / 5) + k + (k / 4) + (j / 4) + (5 * j)) % 7

                        var weekdays = ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri"]
                        var current_day = weekdays[weekday_num]

                        print("Dia da semana:", current_day)
                        print("Horário atual:", current_time)
    			var sensors = json.load(tasmota.read_sensors())
    			var t2 = sensors["DHT11-23"]["Temperature"]
			var t3 = sensors["Switch1"]
                        if current_day == day 
				if ( current_time >= start_time ) && ( current_time < end_time ) && ( t2 < temperature )
	                            if ( pump_index == 1 ) && ( S_power < 5 ) && (t3 == "ON")
					tasmota.set_power(pump_index-1, false)
				    else
					tasmota.set_power(pump_index-1, true)
        	                        print("D " + str(pump_index-1) + " l " + time_part)
				    end
                	        else
                        	    tasmota.set_power(pump_index-1, false)
				end
                        end
                    else
                        print("Evento inválido (não tem 5 partes): " + str(event_data))
                    end
                end
            end
        else
            print("Nenhum evento " + str(pump_index))
        end
    else
        print("Nenhum válido em " + str(pump_index))
    end
end

# Função para verificar os eventos e acioná-los
def check_events()
    if programa != nil && size(programa) > 0
        # Para cada saída (pump_index 1 a 4), processa os eventos
        for i : 1 .. 4
            process_events(i)  # Chama process_events com o índice
        end
    else
        print("Nenhum evento programado.")
    end
end


# Agendamento das funções
tasmota.add_cron("0 */1 * * * *", /-> send_to_thingspeak())
tasmota.add_cron("0 */1 * * * *", /-> check_events())      
load("acc.be")
print("Script Berry carregado.")
