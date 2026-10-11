package main

import (
	"log"
	"net/http"

	"github.com/Gylmynnn/deblue/backend/internal/api"
	"github.com/Gylmynnn/deblue/backend/internal/bluez"
	"github.com/Gylmynnn/deblue/backend/internal/httpx"
	"github.com/Gylmynnn/deblue/backend/internal/ws"
)

func main() {
	bluezClient := bluez.NewClient()
	hub := ws.NewHub()
	handler := api.NewHandler(bluezClient, hub)
	if err := bluezClient.WatchEvents(func(e bluez.Event) {
		hub.Broadcast(e)
	}); err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()
	handler.RegisterRoutes(mux)

	var app http.Handler = mux
	app = httpx.WithLogger(app)
	app = httpx.WithCORS(app)

	server := &http.Server{
		Addr:    "127.0.0.1:8787",
		Handler: app,
	}

	log.Println("Bluetooth backend running at http://127.0.0.1:8787")

	if err := server.ListenAndServe(); err != nil {
		log.Fatal(err)
	}
}
