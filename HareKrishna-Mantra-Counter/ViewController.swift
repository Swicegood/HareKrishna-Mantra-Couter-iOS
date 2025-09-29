/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The root view controller that provides a button to start and stop recording, and which displays the speech recognition results.
*/

import UIKit
import Speech
import AVFoundation

extension UIColor {
    static var parchmentDark: UIColor {
        return UIColor(named: "ParchmentDark") ?? UIColor.darkGray // Fallback color if not found
    }
}

public class ViewController: UIViewController, SFSpeechRecognizerDelegate {
    // MARK: Properties
    private var count = Int()
    private var previousText = ""
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var isDisplayingSanskritText = true
    private var sanskritText = ""
    private var wordBag = [String]()
    private var previousWords = [String]()
    private var recognitionTimer: Timer?
    private let recognitionDuration: TimeInterval = 15.0 // 15 seconds
    private var firstRun = true
    
    // MARK: Microphone Selection Properties
    private var availableInputs: [AVAudioSessionPortDescription] = []
    private var selectedInputIndex: Int = 0
    
    @IBOutlet var textView: UITextView! // Outlet for the first UITextView
    @IBOutlet var resultTextView: UITextView! // Outlet for the second UITextView
    @IBOutlet var recordButton: UIButton!
    @IBOutlet weak var countLabel: UILabel!
    @IBOutlet var clearButton: UIButton!
    @IBOutlet weak var infoButton: UIButton! // Outlet for the info button
    @IBOutlet weak var animationSpeedSlider: UISlider! // Outlet for the slider
    @IBOutlet weak var microphoneStatusLabel: UILabel! // Outlet for microphone status
    @IBOutlet weak var microphoneSelectionButton: UIButton! // Outlet for microphone selection
    
    // MARK: Animation Vars
    var animationLabels:[UILabel] = []
    var words = ["Hare", "Krsna", "Hare", "Krsna", "Krsna", "Krsna", "Hare", "Hare", "Hare", "Rama", "Hare", "Rama", "Rama", "Rama", "Hare", "Hare"]
    var isAnimating = false
    var animationDuration: Double = 0.4 // Default animation duration
    
    // MARK: View Controller Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Disable the record buttons until authorization has been granted.
        recordButton.isEnabled = false
        self.count = UserDefaults.standard.integer(forKey: "chantCount")
        print("Count", self.count)
        textView.text = "Correct Mantras: \(self.count / 16)"
        
        // Add a custom status bar background view
        let statusBarHeight = UIApplication.shared.statusBarFrame.height
        let statusBarBackgroundView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: statusBarHeight))
        statusBarBackgroundView.backgroundColor = .parchmentDark
        view.addSubview(statusBarBackgroundView)
        
        // Set the background color to match the status bar color
        view.backgroundColor = UIColor(named: "Parchment")
        
        // Create a label for each word
        for word in words {
            let label = UILabel()
            label.text = word
            label.textAlignment = .center
            label.textColor = .darkText
            label.font = UIFont(name: "Tangerine-Bold", size: 35)
            label.translatesAutoresizingMaskIntoConstraints = false // Enable Auto Layout for labels
            animationLabels.append(label)
            view.addSubview(label)
        }
        
        // Position the labels in a 4x4 grid on the screen using Auto Layout
        let rows = 4
        let columns = 4
        let gridWidth = view.frame.width / CGFloat(columns)
        let gridHeight = (view.frame.height * 0.3) / CGFloat(rows)
        let topPadding: CGFloat = 100 // Adjust padding as needed
        
        for (index, label) in animationLabels.enumerated() {
            let row = index / columns
            let column = index % columns
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(column) * gridWidth),
                label.topAnchor.constraint(equalTo: view.topAnchor, constant: topPadding + CGFloat(row) * gridHeight),
                label.widthAnchor.constraint(equalToConstant: gridWidth),
                label.heightAnchor.constraint(equalToConstant: gridHeight)
            ])
        }
        
        // Set text size for textView
        textView.font = UIFont.systemFont(ofSize: 20) // Adjust the font size as needed
        
        animationSpeedSlider.value = Float(2.0 - animationDuration) // Reverse the value
        animationSpeedSlider.minimumValue = 1.5
        animationSpeedSlider.maximumValue = 2.0
        animationSpeedSlider.value = Float(animationDuration) // Set default value
        
        // Add tap gesture recognizer to resultTextView
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(resultTextViewTapped))
        resultTextView.addGestureRecognizer(tapGestureRecognizer)
        resultTextView.isUserInteractionEnabled = true
        
        // Set up the resultTextView
        resultTextView.font = UIFont.systemFont(ofSize: 20) // Adjust the font size as needed
        resultTextView.backgroundColor = .white
        resultTextView.layer.borderColor = UIColor.black.cgColor
        resultTextView.layer.borderWidth = 1.0
        resultTextView.translatesAutoresizingMaskIntoConstraints = false
        
        // Bring resultTextView to the front
        view.bringSubviewToFront(resultTextView)
        
        // Add observers for app state transitions
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Initialize microphone selection
        getAvailableAudioInputs()
    }
    
    // Override preferredStatusBarStyle to set the desired status bar style
    public override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // Set to .darkContent if you want dark text on a light background
    }
    
    func scaleUpOneByOne(index: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            if index >= self.animationLabels.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.animationDuration) {
                    self.resetScales()
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.animationDuration) {
                        if self.isAnimating {
                            self.scaleUpOneByOne(index: 0)
                        }
                    }
                }
                return
            }
            
            DispatchQueue.main.async {
                UIView.animate(withDuration: self.animationDuration, animations: {
                    self.animationLabels[index].transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }) { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.animationDuration) {
                        self.scaleUpOneByOne(index: index + 1)
                    }
                }
            }
        }
    }
    
    func resetScales() {
        DispatchQueue.main.async {
            for label in self.animationLabels {
                label.transform = CGAffineTransform.identity
            }
        }
    }
    
    func startAnimation() {
        isAnimating = true
        scaleUpOneByOne(index: 0)
    }
    
    func stopAnimation() {
        isAnimating = false
        resetScales()
    }
    
    @IBAction func recordButtonTapped() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            self.previousText = ""
            recordButton.isEnabled = false
            stopAnimation()
            recordButton.setTitle("Stopping", for: .disabled)
        } else {
            do {
                if !isAnimating {
                    startAnimation()
                }
                recordButton.setTitle("Stop Recording", for: [])
                try startRecording()
            } catch {
                recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Configure the SFSpeechRecognizer object already stored in a local member variable.
        speechRecognizer.delegate = self
        
        // Request microphone permission first
        requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    // Then request speech recognition authorization
                    self?.requestSpeechRecognitionPermission()
                } else {
                    self?.recordButton.isEnabled = false
                    self?.recordButton.setTitle("Microphone access denied", for: .disabled)
                    self?.microphoneSelectionButton?.setTitle("❌ Mic Denied", for: .normal)
                    self?.microphoneSelectionButton?.isEnabled = false
                }
            }
        }
    }
    
    private func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            completion(granted)
        }
    }
    
    private func requestSpeechRecognitionPermission() {
        // Asynchronously make the authorization request.
        SFSpeechRecognizer.requestAuthorization { authStatus in
            
            // Divert to the app's main thread so that the UI can be updated.
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recordButton.isEnabled = true
                    // Refresh audio inputs after permissions are granted
                    self.configureAudioSessionAndRefreshInputs()
                    
                case .denied:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition denied", for: .disabled)
                    
                case .restricted:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition restricted", for: .disabled)
                    
                case .notDetermined:
                    self.recordButton.isEnabled = false
                    self.recordButton.setTitle("Speech recognition not authorized", for: .disabled)
                    
                default:
                    self.recordButton.isEnabled = false
                }
            }
        }
    }
    
    private func startRecording() throws {
        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        // Configure the audio session for the app.
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.allowBluetoothHFP, .duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Refresh available inputs after configuring the session
        getAvailableAudioInputs()
        
        let inputNode = audioEngine.inputNode
        
        // Create and configure the speech recognition request.
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to create a SFSpeechAudioBufferRecognitionRequest object") }
        recognitionRequest.shouldReportPartialResults = true
        
        // Keep speech recognition data on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Create a recognition task for the speech recognition session.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            if let result = result {
                let transcription = result.bestTranscription
                let text = transcription.formattedString
                var words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                self.updateCount(newCount: self.count + 1)
                self.wordBag = words
                
                if self.wordBag.count > 32 {
                    self.wordBag = Array(self.wordBag.suffix(32)) // Truncate to last 32 words
                } else {
                    self.wordBag = Array(repeating: "", count: 32 - self.wordBag.count) + self.wordBag // Pad with empty strings
                }
                
                var unused = 0
                let replacedText = self.replaceEnglishWords(in: self.wordBag.joined(separator: " "), counter: &unused)
                
                if (words.count - replacedText.count) > 0 {
                    self.updateCount(newCount: self.count - 1)
                }
                
                let doubleReplacedText = self.replaceRomanWithSanskrit(in: replacedText, counter: &unused)
                
                self.textView.text = "Correct Mantras: \(self.count / 16)"
                
                self.sanskritText = self.wordBag.joined(separator: " ")
                if self.isDisplayingSanskritText {
                    self.resultTextView.text = doubleReplacedText
                } else {
                    self.resultTextView.text = replacedText
                }
                
                isFinal = result.isFinal
                print("Text \(text)")
            }
            
            if error != nil || isFinal {
                self.stopRecognitionTimer()
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.recordButton.isEnabled = true
                self.recordButton.setTitle("Start Recording", for: [])
            }
        }
        
        // Configure the microphone input.
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Let the user know to start talking.
        textView.text = "(Go ahead, I'm listening)"
        
        // Start the timer to restart recognition every 15 seconds
        startRecognitionTimer()
    }
    
    private func stopRecognition(completion: (() -> Void)? = nil) {
        recognitionTask?.cancel()
        recognitionTask = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        stopRecognitionTimer()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion?()
        }
    }
    
    @objc private func restartRecognition() {
        stopRecognition {
            do {
                try self.startRecording()
                self.recordButton.setTitle("Stop Recording", for: [])
            } catch {
                self.recordButton.setTitle("Recording Not Available", for: [])
            }
        }
    }
    
    // Timer functions
    private func startRecognitionTimer() {
        recognitionTimer = Timer.scheduledTimer(timeInterval: recognitionDuration, target: self, selector: #selector(restartRecognition), userInfo: nil, repeats: true)
    }
    
    private func stopRecognitionTimer() {
        recognitionTimer?.invalidate()
        recognitionTimer = nil
    }
    
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recordButton.isEnabled = true
            recordButton.setTitle("Start Recording", for: [])
        } else {
            recordButton.isEnabled = false
            recordButton.setTitle("Recognition Not Available", for: .disabled)
        }
    }
    
    @IBAction func resetdButtonTapped() {
        let alert = UIAlertController(title: "Are You Sure?", message: "Are you sure you want to reset the count?", preferredStyle: .alert)
        let yesAction = UIAlertAction(title: "Yes", style: .default) { (action) in
            // Reset the count here
            self.updateCount(newCount: 0)
            self.resultTextView.text = ""
        }
        let noAction = UIAlertAction(title: "No", style: .cancel, handler: nil)
        alert.addAction(yesAction)
        alert.addAction(noAction)
        present(alert, animated: true, completion: nil)
    }
    
    // Action for the info button
    @IBAction func infoButtonTapped(_ sender: UIButton) {
        let alert = UIAlertController(title: "Chanting the holy names of the Mahamantra,", message: "is a profound and transformative spiritual practice rooted in the ancient tradition of Bhakti Yoga. This mantra, composed of sacred names of the Supreme Divine, is chanted to evoke a deep connection with God, purify the mind, and awaken one's spiritual consciousness. By repeating these names with sincerity and devotion, one can experience inner peace, joy, and a sense of unity with the divine. This practice is accessible to everyone, regardless of background or prior knowledge, and can be performed anywhere, making it a powerful tool for personal and spiritual growth.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        // Calculate the new animation duration
        let sliderMaxValue: Float = 2.0
        let maxSpeedValue: Float = 1.85 // Adjust as needed for the fastest speed
        
        // Rescale the slider value: map 0.0 to 0.75 to the range [0, maxSpeedValue]
        let scaledValue = min(sender.value / (3.0 / 4.0), 1.0)
        
        // Apply an exponential scaling to make the change more noticeable towards the end
        let newAnimationDuration = pow(Double(scaledValue), 3.0) * Double(maxSpeedValue)
        
        // Update the animation duration
        animationDuration = 2.0 - newAnimationDuration
    }
    
    func replaceEnglishWords(in text: String, counter: inout Int) -> String {
        var replacedText = text.lowercased()
        
        // Words that sound like "Hare"
        let hareWords = [
            "hi", "had", "a", "i", "hade", "hadi", "huddy", "hee", "hai",
            "hello", "today", "hooray", "honey", "hurry", "hari", "how", "are",
            "hoodie"
        ]
        
        // Words that sound like "Krishna"
        let krishnaWords = [
            "krishna", "krish", "christian"
        ]
        
        // Words that sound like "Rama"
        let ramaWords = [
            "rama"
        ]
        
        var wordCounts: [String: Int] = ["Hare": 0, "Krishna": 0, "Rama": 0]
        var filteredWords: [String] = []
        
        let words = replacedText.components(separatedBy: .whitespacesAndNewlines)
        for word in words {
            if hareWords.contains(word) {
                filteredWords.append("Hare")
                wordCounts["Hare"]! += 1
            } else if krishnaWords.contains(word) {
                filteredWords.append("Krishna")
                wordCounts["Krishna"]! += 1
            } else if ramaWords.contains(word) {
                filteredWords.append("Rama")
                wordCounts["Rama"]! += 1
            }
        }
        
        counter += wordCounts["Hare"]! + wordCounts["Krishna"]! + wordCounts["Rama"]!
        replacedText = filteredWords.joined(separator: " ")
        
        return replacedText
    }
    
    func replaceRomanWithSanskrit(in text: String, counter: inout Int) -> String {
        return text.replacingOccurrences(of: "Hare", with: "हरे").replacingOccurrences(of: "Krishna", with: "कृष्णा").replacingOccurrences(of: "Rama", with: "राम")
    }
    
    @objc func resultTextViewTapped() {
        if isDisplayingSanskritText {
            let resultWords = resultTextView.text.components(separatedBy: .whitespacesAndNewlines)
            resultTextView.text = resultWords.joined(separator: " ")
            showMessage("Characters are now Roman")
        } else {
            resultTextView.text = sanskritText // Assuming `originalText` holds the original text
            showMessage("Language changed to Sanskrit")
        }
        isDisplayingSanskritText.toggle()
    }
    
    func showMessage(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            alert.dismiss(animated: true, completion: nil)
        }
    }
    
    func updateCount(newCount: Int) {
        self.count = newCount
        UserDefaults.standard.set(self.count, forKey: "chantCount")
        self.textView.text = "Correct Mantras: \(self.count / 16)"
        
        let resultWords = resultTextView.text
    }
    
    
    @objc private func applicationWillEnterForeground() {
        // Refresh microphone selection when returning to foreground
        configureAudioSessionAndRefreshInputs()
        restartRecognition()
    }
    
    @objc private func applicationDidEnterBackground() {
        stopRecognition()
    }
    
    // MARK: Microphone Selection Methods
    
    private func configureAudioSessionAndRefreshInputs() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .allowBluetoothHFP)
            try audioSession.setActive(true)
            getAvailableAudioInputs()
        } catch {
            print("Failed to configure audio session: \(error)")
            microphoneSelectionButton?.setTitle("❌ Audio Error", for: .normal)
            microphoneSelectionButton?.isEnabled = false
        }
    }
    
    private func getAvailableAudioInputs() {
        let audioSession = AVAudioSession.sharedInstance()
        
        // Ensure audio session is configured for recording
        do {
            if audioSession.category != .record {
                try audioSession.setCategory(.record, mode: .measurement, options: .allowBluetoothHFP)
            }
            try audioSession.setActive(true)
        } catch {
            print("Failed to configure audio session for input checking: \(error)")
            availableInputs = []
            updateMicrophoneStatus()
            return
        }
        
        availableInputs = audioSession.availableInputs ?? []
        
        // Find the current input
        if let currentInput = audioSession.currentRoute.inputs.first {
            for (index, input) in availableInputs.enumerated() {
                if input.uid == currentInput.uid {
                    selectedInputIndex = index
                    break
                }
            }
        }
        
        updateMicrophoneStatus()
    }
    
    private func switchAudioInput(to input: AVAudioSessionPortDescription) throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setPreferredInput(input)
        updateMicrophoneStatus()
    }
    
    private func updateMicrophoneStatus() {
        let audioSession = AVAudioSession.sharedInstance()
        let currentInput = audioSession.currentRoute.inputs.first
        
        var statusText = "🎤 Unknown"
        
        if let input = currentInput {
            switch input.portType {
            case .bluetoothA2DP, .bluetoothLE:
                statusText = "🎧 AirPods"
            case .builtInMic:
                statusText = "📱 Phone Mic"
            case .headsetMic:
                statusText = "🎧 Headset"
            case .bluetoothHFP:
                statusText = "🎧 Bluetooth"
            default:
                statusText = "🎤 \(input.portType.rawValue)"
            }
        }
        
        microphoneStatusLabel?.text = statusText
        
        // Update microphone selection button
        if availableInputs.count > 1 {
            microphoneSelectionButton?.setTitle("🔄 Switch", for: .normal)
            microphoneSelectionButton?.isEnabled = true
        } else {
            microphoneSelectionButton?.setTitle("❌ No Options", for: .normal)
            microphoneSelectionButton?.isEnabled = false
        }
        
        print("Currently using: \(statusText)")
    }
    
    @IBAction func microphoneSelectionButtonTapped(_ sender: UIButton) {
        guard availableInputs.count > 1 else { return }
        
        let alert = UIAlertController(title: "Select Microphone", message: "Choose which microphone to use for recording", preferredStyle: .actionSheet)
        
        for (index, input) in availableInputs.enumerated() {
            let baseTitle = "\(input.portName) (\(input.portType.rawValue))"
            let title = (index == selectedInputIndex) ? "✓ " + baseTitle : baseTitle
            let action = UIAlertAction(title: title, style: .default) { _ in
                do {
                    try self.switchAudioInput(to: input)
                    self.selectedInputIndex = index
                } catch {
                    self.showMessage("Failed to switch microphone: \(error.localizedDescription)")
                }
            }

            if index == selectedInputIndex {
                if #available(iOS 13.0, *) {
                    action.setValue(UIImage(systemName: "checkmark"), forKey: "image")
                }
                // On earlier iOS versions, the title already includes a checkmark character.
            }

            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // For iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sender
            popover.sourceRect = sender.bounds
        }
        
        present(alert, animated: true)
    }
    
}
