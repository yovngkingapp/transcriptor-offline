import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioRecorder _recorder = AudioRecorder();
  final WhisperFlutterNew _whisper = WhisperFlutterNew();
  bool _isRecording = false;
  String _transcription = '';
  String _status = 'Presiona para grabar';
  String? _audioPath;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
    await Permission.storage.request();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Detener y transcribir
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        setState(() {
          _status = 'Transcribiendo... (esto puede tardar)';
          _audioPath = path;
        });

        try {
          final transcription = await _whisper.transcribe(
            audioPath: path,
            model: 'base',           // Cambia a 'tiny' si es muy lento, o 'small' si tu celular es potente
            language: 'es',          // español
          );

          setState(() {
            _transcription = transcription.text;
            _status = 'Transcripción lista';
          });

          // Guardar archivo de texto (opcional)
          await _saveTranscription(transcription.text);
        } catch (e) {
          setState(() => _status = 'Error al transcribir: $e');
        }
      }
    } else {
      // Empezar a grabar
      final dir = await getApplicationDocumentsDirectory();
      final path = '${dir.path}/${_uuid.v4()}.m4a';

      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 16000,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _status = 'Grabando...';
        _transcription = '';
      });
    }
  }

  Future<void> _saveTranscription(String text) async {
    if (_audioPath == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/nota_${DateTime.now().millisecondsSinceEpoch}.txt');
    await file.writeAsString('Audio: $_audioPath\n\nTranscripción:\n$text');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transcriptor Offline Whisper')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Estado
            Text(
              _status,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // Botón grande de grabar
            GestureDetector(
              onTap: _toggleRecording,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop : Icons.mic,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),

            const SizedBox(height: 30),

            const Text('Mantén presionado el botón grande para grabar y soltar para transcribir',
                textAlign: TextAlign.center),

            const SizedBox(height: 40),

            // Resultado de transcripción
            if (_transcription.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Card(
                    color: Colors.grey[900],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _transcription,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
