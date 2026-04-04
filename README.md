# ElevenLabs API for Godot

- [✨ Features](#-features)
- [📦 Installation](#-installation)
- [⚙️ Usage](#️-usage)
- [🤝 Contributing](#-contributing)
- [📜 License](#-license)

A Godot Plugin that allows high-quality Text-to-Speech utilizing ElevenLabs API.

See how simple it is:

https://github.com/user-attachments/assets/a58cd6f6-d013-4edd-8cc6-251969f820ab

---

### ✨ Features

- Text-to-Speech
- (planned) Speech-to-Text
- (planned) Multi-request handling
- (planned) Internal API for runtime request handling

---

### 📦 Installation

1. Either:
   1. Install this repository as submodule into your git project with command `git submodule add https://github.com/Wiechciu/eleven-labs.git addons/eleven_labs`.
   2. Or copy the contents of this repository folder into your Godot project’s `addons/eleven_labs` directory.
2. In Godot, go to **Project > Project Settings > Plugins**.
3. Enable **ElevenLabs** Plugin.

<img width="756" height="148" alt="image" src="https://github.com/user-attachments/assets/ee478ed7-7ed2-4cf2-bea0-cf12faac436f" />

---

### ⚙️ Usage

1. Create an API Key at https://elevenlabs.io/app/api/api-keys and enter it in the **API key** field.
2. Click **Load voices** to load all your voices from ElevenLabs, then select your desired voice.
3. Enter **language** and **text** you want to convert into speech.
4. Optionally, specify the **output path** and if the audio file should **play immediately** after being retrieved.
5. Click **Generate** to send request to ElevenLabs and enjoy the outcome.

<img width="929" height="260" alt="image" src="https://github.com/user-attachments/assets/c93d1f64-7794-4ecd-bfbd-185224c5c29c" />

---

### 🤝 Contributing

[Pull requests](https://github.com/Wiechciu/eleven-labs/pulls), [bug reports](https://github.com/Wiechciu/eleven-labs/issues), and [suggestions](https://github.com/Wiechciu/eleven-labs/issues) are welcome!

If you’d like to add features, feel free to fork and submit a PR.

For ElevenLabs API reference, check https://elevenlabs.io/docs/api-reference

---

### 📜 License

[MIT License](https://github.com/Wiechciu/eleven-labs?tab=MIT-1-ov-file) – feel free to use in commercial or open-source projects.
