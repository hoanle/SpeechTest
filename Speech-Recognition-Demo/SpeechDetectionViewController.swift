//
//  SpeechDetectionViewController.swift
//  Speech-Recognition-Demo
//
//  Created by Jennifer A Sipila on 3/3/17.
//  Copyright © 2017 Jennifer A Sipila. All rights reserved.
//

import UIKit
import Speech
import RxSwift
import RxCocoa

class SpeechDetectionViewController: UIViewController, SFSpeechRecognizerDelegate {

    @IBOutlet weak var detectedTextLabel: UILabel!
    @IBOutlet weak var colorView: UIView!
    @IBOutlet weak var startButton: UIButton!
    
    @IBOutlet weak var language: UIButton!
    let audioEngine = AVAudioEngine()
    var speechRecognizer: SFSpeechRecognizer? = SFSpeechRecognizer.init(locale: Locale.init(identifier: "en"))
    var request: SFSpeechAudioBufferRecognitionRequest? = nil
    var recognitionTask: SFSpeechRecognitionTask?
    var isRecording = false
    var disposalBag: DisposeBag?
    var currentLanguage: String = "en"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.requestSpeechAuthorization()
    }
    
    func runTimer() {
        print("Runtimer")
        disposalBag = DisposeBag()
        
        Observable<Int>.interval(45, scheduler: MainScheduler.instance)
            .map { Double($0) }
            .subscribe({ value in
                print(value)
                self.continueAfter1Minute()
            }).disposed(by: disposalBag!)
    }
    
    func continueAfter1Minute() {
        if isRecording == true {
            request?.endAudio()
            audioEngine.stop()
            if let node = audioEngine.inputNode {
                node.removeTap(onBus: 0)
            }
            
            recognitionTask?.cancel()
            request = nil
            
            try! self.recordAndRecognizeSpeech()
        }
    }
    
    func reset(locale: String) {
        currentLanguage = locale
        if isRecording == true {
            request?.endAudio()
            audioEngine.stop()
            
            if let node = audioEngine.inputNode {
                node.removeTap(onBus: 0)
            }
            
            recognitionTask?.cancel()
            isRecording = false
            detectedTextLabel.text = ""
            startButton.backgroundColor = UIColor.gray
            colorView.backgroundColor = UIColor.gray
            request = nil
        }
        speechRecognizer = SFSpeechRecognizer.init(locale: Locale.init(identifier: locale))
        
        try! self.recordAndRecognizeSpeech()
        isRecording = true
        startButton.backgroundColor = UIColor.red
    }
    
    @IBAction func setKorean(_ sender: Any) {
        language.titleLabel?.text = "Korean"
        reset(locale: "ko-KR")
    }
    
    @IBAction func setArabic(_ sender: Any) {
        language.titleLabel?.text = "Arabic"
        reset(locale: "ar-SA")
    }
    
    @IBAction func setEnglish(_ sender: Any) {
        language.titleLabel?.text = "English"
        reset(locale: "en")
    }
    
    @IBAction func setVietnamese(_ sender: Any) {
        language.titleLabel?.text = "Hindi"
        reset(locale: "hi-IN")
    }
    
    //MARK: IBActions and Cancel
    
    @IBAction func startButtonTapped(_ sender: UIButton) {
        if isRecording == true {
            request?.endAudio()
            audioEngine.stop()
            if let node = audioEngine.inputNode {
                node.removeTap(onBus: 0)
            }
            
            recognitionTask?.cancel()
            isRecording = false
            detectedTextLabel.text = ""
            startButton.backgroundColor = UIColor.gray
            colorView.backgroundColor = UIColor.gray
            request = nil
        } else {
            if (disposalBag == nil) {
                 runTimer()
            }
        
            try! self.recordAndRecognizeSpeech()
            isRecording = true
            startButton.backgroundColor = UIColor.red
        }
    }

    func cancelRecording() {
        audioEngine.stop()
        if let node = audioEngine.inputNode {
            node.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
    }
    
//MARK: - Recognize Speech

    func recordAndRecognizeSpeech() throws {
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeDefault)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        try audioSession.setPreferredSampleRate(24000) //Sameple Rate
        
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let node = audioEngine.inputNode else { return }
        
        let recordingFormat = node.outputFormat(forBus: 0)
        request?.shouldReportPartialResults = true
        request?.taskHint = SFSpeechRecognitionTaskHint.search //Task Hint
        
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            self.sendAlert(message: "There has been an audio engine error.")
            return print(error)
        }
        guard let myRecognizer = SFSpeechRecognizer() else {
            self.sendAlert(message: "Speech recognition is not supported for your current locale.")
            return
        }
        if !myRecognizer.isAvailable {
            self.sendAlert(message: "Speech recognition is not currently available. Check back at a later time." )
            // Recognizer is not available right now
            return
        }
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request!, resultHandler: { result, error in
            if result != nil {
                if let result = result {
                    
                    var bestString = result.bestTranscription.formattedString
                    print("\(bestString.count)")
                    
                    
                    var lastString: String = ""
                    for segment in result.bestTranscription.segments {
                        let indexTo = bestString.index(bestString.startIndex, offsetBy: segment.substringRange.location)
                        lastString = bestString.substring(from: indexTo)
                    }
                    
                    self.checkForColorsSaid(resultString: lastString)
                    
                    if bestString.count > 200 {
                        let index100 = bestString.index(bestString.startIndex, offsetBy: 200)
                        bestString = bestString.substring(from: index100)
                    }
                    
                    self.detectedTextLabel.text = bestString
                } else if let error = error {
                    self.sendAlert(message: "There has been a speech recognition error.")
                    print(error)
                }
            }
        })
    }
    
//MARK: - Check Authorization Status

func requestSpeechAuthorization() {
    SFSpeechRecognizer.requestAuthorization { authStatus in
        OperationQueue.main.addOperation {
            switch authStatus {
            case .authorized:
                self.startButton.isEnabled = true
            case .denied:
                self.startButton.isEnabled = false
                self.detectedTextLabel.text = "User denied access to speech recognition"
            case .restricted:
                self.startButton.isEnabled = false
                self.detectedTextLabel.text = "Speech recognition restricted on this device"
            case .notDetermined:
                self.startButton.isEnabled = false
                self.detectedTextLabel.text = "Speech recognition not yet authorized"
            }
        }
    }
}
    
//MARK: - UI / Set view color.
    
    func checkForColorsSaid(resultString: String) {
        switch resultString {
        case "red":
            colorView.backgroundColor = UIColor.red
        case "orange":
            colorView.backgroundColor = UIColor.orange
        case "yellow":
            colorView.backgroundColor = UIColor.yellow
        case "green":
            colorView.backgroundColor = UIColor.green
        case "blue":
            colorView.backgroundColor = UIColor.blue
        case "purple":
            colorView.backgroundColor = UIColor.purple
        case "black":
            colorView.backgroundColor = UIColor.black
        case "white":
            colorView.backgroundColor = UIColor.white
        case "gray":
            colorView.backgroundColor = UIColor.gray
        default: break
        }
    }
    
//MARK: - Alert
    
    func sendAlert(message: String) {
        let alert = UIAlertController(title: "Speech Recognizer Error", message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
