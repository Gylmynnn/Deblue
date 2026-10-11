package api

import (
	"encoding/json"
	"net/http"

	"github.com/Gylmynnn/deblue/backend/internal/bluez"
	"github.com/Gylmynnn/deblue/backend/internal/httpx"
	"github.com/Gylmynnn/deblue/backend/internal/models"
	"github.com/Gylmynnn/deblue/backend/internal/ws"
)

type Handler struct {
	bluez *bluez.Client
	hub   *ws.Hub
}

func NewHandler(bluezClient *bluez.Client, hub *ws.Hub) *Handler {
	return &Handler{
		bluez: bluezClient,
		hub:   hub,
	}
}

func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("/", h.health)
	mux.HandleFunc("/adapter", h.getAdapter)
	mux.HandleFunc("/adapter/power", h.setAdapterPower)

	mux.HandleFunc("/scan/start", h.startScan)
	mux.HandleFunc("/scan/stop", h.stopScan)

	mux.HandleFunc("/devices", h.getDevices)
	mux.HandleFunc("/devices/connect", h.connectDevice)
	mux.HandleFunc("/devices/disconnect", h.disconnectDevice)
	mux.HandleFunc("/devices/pair", h.pairDevice)
	mux.HandleFunc("/devices/trust", h.trustDevice)
	mux.HandleFunc("/devices/untrust", h.untrustDevice)
	mux.HandleFunc("/devices/remove", h.removeDevice)
	mux.HandleFunc("/events", h.events)
}

func (h *Handler) health(w http.ResponseWriter, r *http.Request) {
	httpx.JSON(w, http.StatusOK, "Bluetooth backend is running", nil)
}

func (h *Handler) events(w http.ResponseWriter, r *http.Request) {
	h.hub.HandleWS(w, r)
}

func (h *Handler) getAdapter(w http.ResponseWriter, r *http.Request) {
	adapter, err := h.bluez.GetAdapter()
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	httpx.JSON(w, http.StatusOK, "Adapter fetched", adapter)
}

func (h *Handler) setAdapterPower(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpx.Error(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var body models.AdapterPowerRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httpx.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	if err := h.bluez.SetAdapterPower(body.Powered); err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	httpx.JSON(w, http.StatusOK, "Bluetooth power updated", map[string]bool{
		"powered": body.Powered,
	})
}

func (h *Handler) startScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpx.Error(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	if err := h.bluez.StartScan(); err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	httpx.JSON(w, http.StatusOK, "Scan started", nil)
}

func (h *Handler) stopScan(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		httpx.Error(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	if err := h.bluez.StopScan(); err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	httpx.JSON(w, http.StatusOK, "Scan stopped", nil)
}

func (h *Handler) getDevices(w http.ResponseWriter, r *http.Request) {
	devices, err := h.bluez.GetDevices()
	if err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	httpx.JSON(w, http.StatusOK, "Devices fetched", devices)
}

func (h *Handler) connectDevice(w http.ResponseWriter, r *http.Request) {
	h.handleDeviceAction(w, r, h.bluez.ConnectDevice, "Device connected")
}

func (h *Handler) disconnectDevice(w http.ResponseWriter, r *http.Request) {
	h.handleDeviceAction(w, r, h.bluez.DisconnectDevice, "Device disconnected")
}

func (h *Handler) pairDevice(w http.ResponseWriter, r *http.Request) {
	h.handleDeviceAction(w, r, h.bluez.PairDevice, "Device paired")
}

func (h *Handler) trustDevice(w http.ResponseWriter, r *http.Request) {
	h.handleDeviceAction(w, r, func(path string) error {
		return h.bluez.SetDeviceTrusted(path, true)
	}, "Device trusted")
}

func (h *Handler) untrustDevice(w http.ResponseWriter, r *http.Request) {
	h.handleDeviceAction(w, r, func(path string) error {
		return h.bluez.SetDeviceTrusted(path, false)
	}, "Device untrusted")
}

func (h *Handler) removeDevice(w http.ResponseWriter, r *http.Request) {
	h.handleDeviceAction(w, r, h.bluez.RemoveDevice, "Device removed")
}

func (h *Handler) handleDeviceAction(
	w http.ResponseWriter,
	r *http.Request,
	action func(path string) error,
	successMessage string,
) {
	if r.Method != http.MethodPost {
		httpx.Error(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var body models.DeviceActionRequest
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		httpx.Error(w, http.StatusBadRequest, err.Error())
		return
	}

	if body.Path == "" {
		httpx.Error(w, http.StatusBadRequest, "Device path is required")
		return
	}

	if err := action(body.Path); err != nil {
		httpx.Error(w, http.StatusInternalServerError, err.Error())
		return
	}

	httpx.JSON(w, http.StatusOK, successMessage, nil)
}
