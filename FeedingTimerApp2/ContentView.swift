import SwiftUI
import Speech
import AVFoundation

struct FeedingLog: Identifiable, Codable {
    var id: UUID
    var side: String
    var duration: Int
    var date: Date
}

struct ContentView: View {
    @State private var timer: Timer? = nil
    @State private var elapsedTime = 0
    @State private var isRunning = false
    @State private var selectedSide = ""
    @State private var logs: [FeedingLog] = []
    @State private var lastFeedingLog: FeedingLog?
    @State private var audioEngine: AVAudioEngine?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var isListening = false
    @State private var showDeleteAlert = false   // ポップアップ制御用

    // 配色パレット
    let background = Color(red: 1.0, green: 0.98, blue: 0.97)
    let mainBox = Color(red: 1.0, green: 0.92, blue: 0.94)
    let accentBlue = Color(red: 0.80, green: 0.90, blue: 1.0)
    let softOrange = Color(red: 1.0, green: 0.78, blue: 0.48)
    let lavender = Color(red: 0.96, green: 0.94, blue: 1.0)
    let commandBox = Color(red: 0.88, green: 0.98, blue: 1.0)
    let whiteBox = Color.white
    let pinkBox = Color(red: 1.0, green: 0.72, blue: 0.83)
    let darkText = Color(red: 0.22, green: 0.19, blue: 0.19)

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // タイトル
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        Text("🍼")
                            .font(.system(size: 32))
                        Text("音声授乳タイマー")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                    // ここに音声認証状態のテキスト（アニメーション無し！）
                    if isListening {
                        Text("音声入力可能")
                            .foregroundColor(softOrange)
                            .font(.headline)
                            .padding(.top, 8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 22)
                .padding(.bottom, 16)
                .background(accentBlue.opacity(0.7))
                .cornerRadius(26)
                .shadow(color: .blue.opacity(0.08), radius: 10, x: 0, y: 6)
                .padding(.horizontal)

                // 音声認識ボタン
                if !isListening {
                    Button(action: {
                        startSpeechRecognition()
                    }) {
                        VStack(spacing: 0) {
                            Text("最初に押してください")
                                .font(.headline)
                            Text("（音声入力が可能になります）")
                                .font(.system(size: 15))
                                .foregroundColor(.white.opacity(0.84))
                        }
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .frame(height: 90)
                        .background(softOrange)
                        .foregroundColor(.white)
                        .cornerRadius(18)
                        .shadow(color: softOrange.opacity(0.19), radius: 6, x: 0, y: 4)
                    }
                    .padding(.top, 16)
                    .padding(.horizontal)
                }

                // 「右」か「左」か声に出してから〜 のガイド文
                if selectedSide.isEmpty {
                    Text("「右」か「左」と声に出してから「スタート」と話してください")
                        .font(.system(size: 16))
                        .foregroundColor(darkText.opacity(0.75))
                        .padding(.top, 12)
                        .padding(.horizontal, 30)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .background(background)
                }

                // おっぱい選択ボックス（選択時のみ）
                if !selectedSide.isEmpty {
                    Text(selectedSide == "右"
                        ? "右おっぱいを飲ませてください"
                        : "左おっぱいをのませてください")
                        .font(.title3)
                        .foregroundColor(.black)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(mainBox)
                                .shadow(color: .pink.opacity(0.14), radius: 7, x: 0, y: 2)
                        )
                        .padding(.horizontal, 32)
                        .padding(.bottom, 4)
                }

                // タイマーボックス
                Text(formatTime(elapsedTime))
                    .font(.largeTitle)
                    .foregroundColor(.black)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(mainBox)
                            .shadow(color: .pink.opacity(0.14), radius: 7, x: 0, y: 2)
                    )
                    .padding(.horizontal, 32)
                    .padding(.top, 8)

                // 授乳記録
                VStack(alignment: .leading, spacing: 8) {
                    Text("授乳記録（50件まで）")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding(.leading, 2)
                        .padding(.bottom, 2)
                    VStack(spacing: 0) {
                        ForEach(logs.reversed()) { log in
                            HStack {
                                Text(log.side)
                                    .foregroundColor(.blue)
                                Spacer()
                                Text(formatTime(log.duration))
                                    .foregroundColor(.blue)
                                Text(formatDate(log.date))
                                    .foregroundColor(.gray)
                                    .font(.caption)
                                    .padding(.leading, 8)
                                Button(action: { deleteLog(log) }) { Text("削除").foregroundColor(.pink) }
                            }
                            .padding(.vertical, 4)
                            .background(whiteBox.opacity(0.95))
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)

                // 音声での操作方法
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                        Text("音声での操作方法")
                            .font(.headline)
                            .bold()
                            .foregroundColor(.black)
                        Spacer()
                    }
                    HStack {
                        Text("右")
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pinkBox)
                            .foregroundColor(darkText)
                            .font(.headline)
                            .cornerRadius(8)
                        Text("または").foregroundColor(.gray)
                        Text("左")
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pinkBox)
                            .foregroundColor(darkText)
                            .font(.headline)
                            .cornerRadius(8)
                        Text("- 胸を選択").foregroundColor(.gray)
                    }
                    HStack {
                        Text("スタート")
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pinkBox)
                            .foregroundColor(darkText)
                            .font(.headline)
                            .cornerRadius(8)
                        Text("- タイマー開始").foregroundColor(.gray)
                    }
                    HStack {
                        Text("ストップ")
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pinkBox)
                            .foregroundColor(darkText)
                            .font(.headline)
                            .cornerRadius(8)
                        Text("- タイマー一時停止").foregroundColor(.gray)
                    }
                    HStack {
                        Text("完了")
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pinkBox)
                            .foregroundColor(darkText)
                            .font(.headline)
                            .cornerRadius(8)
                        Text("- 記録を保存").foregroundColor(.gray)
                    }
                    HStack {
                        Text("リセット")
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(pinkBox)
                            .foregroundColor(darkText)
                            .font(.headline)
                            .cornerRadius(8)
                        Text("- タイマーをリセット").foregroundColor(.gray)
                    }
                }
                .padding()
                .background(commandBox)
                .cornerRadius(18)
                .padding(.horizontal)
                .padding(.top, 26)
                .padding(.bottom, 8)

                // 「ログを全て削除」ボタン
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("ログを全て削除")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(lavender)
                        .foregroundColor(.pink)
                        .cornerRadius(16)
                        .shadow(color: lavender.opacity(0.19), radius: 3, x: 0, y: 2)
                }
                .padding([.bottom, .horizontal, .top])
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("確認"),
                        message: Text("ログを全て削除してもよろしいですか？"),
                        primaryButton: .destructive(Text("はい")) {
                            deleteAllLogs()
                        },
                        secondaryButton: .cancel(Text("いいえ"))
                    )
                }
            }
            .padding(.top)
        }
        .background(background.edgesIgnoringSafeArea(.all))
        .onAppear {
            loadLogs()
            checkPreviousLog()
        }
    }

    // --- ロジック部 ---
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }
    func startTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.elapsedTime += 1
        }
    }
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    func resetTimer() {
        elapsedTime = 0
        selectedSide = ""
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    func completeTimer() {
        guard !selectedSide.isEmpty else { return }
        let newLog = FeedingLog(id: UUID(), side: selectedSide, duration: elapsedTime, date: Date())
        logs.append(newLog)
        if logs.count > 50 { logs.removeFirst() }
        saveLogs()
        checkPreviousLog()
        resetTimer()
    }
    func selectSide(_ side: String) {
        if self.selectedSide == side { return }
        if isRunning { return }
        self.selectedSide = side
    }
    func deleteAllLogs() {
        logs.removeAll()
        saveLogs()
        checkPreviousLog()
    }
    func deleteLog(_ log: FeedingLog) {
        logs.removeAll { $0.id == log.id }
        saveLogs()
    }
    func saveLogs() {
        if let encoded = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(encoded, forKey: "feedingLogs")
        }
    }
    func loadLogs() {
        if let savedData = UserDefaults.standard.data(forKey: "feedingLogs"),
           let decoded = try? JSONDecoder().decode([FeedingLog].self, from: savedData) {
            logs = decoded
        }
    }
    func checkPreviousLog() {
        lastFeedingLog = logs.last
    }
    func formatTime(_ time: Int) -> String {
        let minutes = time / 60
        let seconds = time % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    // 音声認識関連
    func startSpeechRecognition() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    print("マイクの許可がありません")
                    return
                }
                SFSpeechRecognizer.requestAuthorization { status in
                    DispatchQueue.main.async {
                        if status == .authorized {
                            isListening = true
                            runRecognition()
                        } else {
                            print("音声認識の許可が得られませんでした。")
                        }
                    }
                }
            }
        }
    }
    func runRecognition() {
        audioEngine?.stop()
        audioEngine = AVAudioEngine()
        let audioEngine = self.audioEngine!
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("マイク設定エラー: \(error.localizedDescription)")
        }
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("audioEngine開始エラー: \(error.localizedDescription)")
        }
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
        recognitionTask = recognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                let recognizedText = result.bestTranscription.formattedString
                print("認識結果: \(recognizedText)")
                processVoiceCommand(command: recognizedText)
                if result.isFinal {
                    audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    isListening = false
                }
            } else if let error = error {
                print("音声認識エラー: \(error.localizedDescription)")
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                isListening = false
            }
        }
    }
    func processVoiceCommand(command: String) {
        if command.hasSuffix("右") && selectedSide != "右" && !isRunning {
            selectSide("右")
        }
        if command.hasSuffix("左") && selectedSide != "左" && !isRunning {
            selectSide("左")
        }
        if command.hasSuffix("スタート") {
            print("[DEBUG] isRunning:\(isRunning), selectedSide:\(selectedSide)")
            if !isRunning && !selectedSide.isEmpty {
                startTimer()
            }
        }
        if command.hasSuffix("ストップ") {
            if isRunning {
                stopTimer()
            }
        }
        if command.hasSuffix("リセット") {
            resetTimer()
        }
        if command.hasSuffix("完了") {
            completeTimer()
        }
    }
}
