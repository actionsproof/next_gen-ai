package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

var (
	Version = "v0.1.0"
	Commit  = "dev"
	Date    = "" // injected via -ldflags at build time
)

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("ok"))
	})
	mux.HandleFunc("/version", func(w http.ResponseWriter, r *http.Request) {
		resp := map[string]string{"version": Version, "commit": Commit, "date": Date}
		json.NewEncoder(w).Encode(resp)
	})
	mux.HandleFunc("/run", func(w http.ResponseWriter, r *http.Request) {
		// Placeholder deterministic response
		resp := map[string]any{"timestamp": time.Now().UTC().Format(time.RFC3339), "result": "stub"}
		json.NewEncoder(w).Encode(resp)
	})

	port := os.Getenv("PORT")
	if port == "" { port = "8080" }
	log.Printf("starting server on :%s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Fatal(err)
	}
}
