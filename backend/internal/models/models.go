package models

type AdapterInfo struct {
	Powered     bool   `json:"powered"`
	Discovering bool   `json:"discovering"`
	Address     string `json:"address"`
	Name        string `json:"name"`
	Alias       string `json:"alias"`
}

type Device struct {
	Path      string `json:"path"`
	Name      string `json:"name"`
	Address   string `json:"address"`
	Connected bool   `json:"connected"`
	Paired    bool   `json:"paired"`
	Trusted   bool   `json:"trusted"`
	RSSI      int16  `json:"rssi"`
}

type DeviceActionRequest struct {
	Path string `json:"path"`
}

type AdapterPowerRequest struct {
	Powered bool `json:"powered"`
}
