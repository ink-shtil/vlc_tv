# 1) allow remote control

# ssh root@192.168.0.15

# 2) send command via http jsonrpc
curl --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playe
r.PlayPause\",\"params\":{\"playerid\":1},\"id\":1}" "http://localhost:8080/jsonrpc"


curl --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1},\"id\":1}" "http://localhost:8080/jsonrpc"
curl --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Clear\",\"params\":{\"playlistid\":1},\"id\":1}" "http://localhost:8080/jsonrpc"

curl --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1,\"item\":{\"file\":\"$random_item\"}},\"id\":1}" "http://localhost:8080/jsonrpc"
curl --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1,\"item\":{\"file\":\"$random_item\"}},\"id\":1}" "http://localhost:8080/jsonrpc"
curl --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Playlist.Add\",\"params\":{\"playlistid\":1,\"item\":{\"file\":\"/media/SanDisk/videos/russian/DMB.avi\"}},\"id\":1}" "http://localhost:8080/jsonrpc"

curl -s --header "Content-Type: application/json" --data "{\"jsonrpc\":\"2.0\",\"method\":\"Player.Seek\",\"params\":{\"playerid\":1,\"value\":25},\"id\":1}" "http://localhost:8080/jsonrpc"