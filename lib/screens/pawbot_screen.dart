import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/pawbot_service.dart';

// ============================================================================
// PANTALLA DEL ASISTENTE VIRTUAL INTELIGENTE (PawBotScreen)
// Permite a estudiantes y personal de la ESPOCH realizar consultas por texto
// o por voz (micrófono) sobre caninos registrados, vacunación, historial
// médico, incidencias, cuidado general canino y funcionamiento de Paw Track.
// ============================================================================
class PawBotScreen extends StatefulWidget {
  final AppUser user;
  const PawBotScreen({super.key, required this.user});

  @override
  State<PawBotScreen> createState() => _PawBotScreenState();
}

class _PawBotScreenState extends State<PawBotScreen> {
  static const MethodChannel _nativeChannel =
      MethodChannel('ec.edu.espoch.pawtrack/notifications');

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<PawBotMessage> _messages = [];
  bool _isTyping = false;
  bool _isListeningVoice = false;

  // Preguntas sugeridas para facilitar la interacción rápida
  static const List<String> _suggestedQuestions = [
    '¿Cuántos caninos están registrados?',
    '¿Qué vacunas están registradas?',
    '¿Qué incidencias están pendientes?',
    '¿Cuál es el historial médico?',
    '¿Cómo puedo reportar una incidencia?',
    '¿Qué cuidados necesita un cachorro?',
    '¿Qué significa el collar rojo?',
    'Contactos de emergencia ESPOCH',
  ];

  @override
  void initState() {
    super.initState();
    final firstName = widget.user.name.trim().isNotEmpty
        ? widget.user.name.trim().split(' ').first
        : 'usuario';
    final roleName = widget.user.isStaff ? 'Personal' : 'Estudiante';

    // Mensaje inicial de bienvenida
    _messages.add(
      PawBotMessage(
        text:
            '¡Hola, **$firstName**! Soy **PawBot** 🐾, el asistente virtual inteligente de **Paw Track ESPOCH** (Sesión activa: *$roleName*).\n\n'
            'Puedo ayudarte a consultar en tiempo real:\n'
            '• **Caninos registrados** en el campus, edades y rasgos\n'
            '• **Vacunas**, fechas aplicadas y próximas dosis\n'
            '• **Historial médico** y atenciones veterinarias\n'
            '• **Incidencias** y reportes según tus permisos\n'
            '• **Cuidado canino** y ayuda para usar la aplicación\n\n'
            'Selecciona una pregunta sugerida, escribe o toca el micrófono para hablar:',
        isUser: false,
        sourceLabel: 'Asistente PawBot ESPOCH',
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? presetQuestion]) async {
    final text = (presetQuestion ?? _inputController.text).trim();
    if (text.isEmpty || _isTyping) return;

    _inputController.clear();

    setState(() {
      _messages.add(PawBotMessage(text: text, isUser: true));
      _isTyping = true;
    });
    _scrollToBottom();

    final reply = await PawBotService.ask(
      question: text,
      user: widget.user,
      history: _messages,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _isTyping = false;
    });
    _scrollToBottom();
  }

  /// Activa el reconocimiento de voz nativo de Android (Speech-to-Text) para
  /// que el usuario pueda hablar su consulta y recibir la respuesta de PawBot.
  Future<void> _startVoiceInput() async {
    if (_isTyping || _isListeningVoice) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'El dictado por voz está disponible en la aplicación móvil Android.'),
        ),
      );
      return;
    }

    setState(() => _isListeningVoice = true);
    try {
      final spokenText =
          await _nativeChannel.invokeMethod<String>('startVoiceInput');
      if (!mounted) return;
      setState(() => _isListeningVoice = false);

      final cleanSpoken = (spokenText ?? '').trim();
      if (cleanSpoken.isNotEmpty) {
        _inputController.text = cleanSpoken;
        await _sendMessage(cleanSpoken);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isListeningVoice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se pudo iniciar el micrófono. Verifica que tu dispositivo tenga entrada de voz de Google activa.'),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _clearChat() {
    setState(() {
      final welcome = _messages.first;
      _messages
        ..clear()
        ..add(welcome);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Botón para regresar a la pantalla principal
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: Color(0xFF0F2B48),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Icono representativo del asistente canino PawBot
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D3B73), Color(0xFF1E5BB0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D3B73).withValues(alpha: 0.20),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.pets_rounded,
                          color: Colors.white, size: 20),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // Nombre del asistente y subtítulo limpio sin desbordamiento (overflow)
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'PawBot',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0B2545),
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              widget.user.isStaff ? 'Personal' : 'Estudiante',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E5BB0),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Asistente inteligente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón para limpiar conversación
                IconButton(
                  tooltip: 'Reiniciar conversación',
                  onPressed: _clearChat,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Lista de mensajes de la conversación
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return const _TypingIndicatorBubble();
                }
                final msg = _messages[index];
                return _ChatBubble(message: msg);
              },
            ),
          ),

          // Carrusel horizontal de preguntas sugeridas
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedQuestions.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final q = _suggestedQuestions[index];
                return ActionChip(
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD0DBF5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  avatar: const Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: Color(0xFF1E5BB0),
                  ),
                  label: Text(
                    q,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F2B48),
                    ),
                  ),
                  onPressed: _isTyping ? null : () => _sendMessage(q),
                );
              },
            ),
          ),

          // Barra inferior de entrada de texto, micrófono y botón de envío
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: const Border(
                top: BorderSide(color: Color(0xFFE2E8F0)),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2545).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Escribe o usa el micrófono...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13.5,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: Color(0xFFD0DBF5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide:
                              const BorderSide(color: Color(0xFFD0DBF5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                              color: Color(0xFF1E5BB0), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón de micrófono para dictar preguntas por voz (Audio -> Texto -> Respuesta)
                  Tooltip(
                    message: 'Hablar por micrófono',
                    child: Material(
                      color: _isListeningVoice
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFEFF6FF),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _isTyping ? null : _startVoiceInput,
                        child: SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            _isListeningVoice
                                ? Icons.mic_rounded
                                : Icons.mic_none_rounded,
                            color: _isListeningVoice
                                ? Colors.white
                                : const Color(0xFF1E5BB0),
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Botón para enviar el mensaje
                  Material(
                    color: _isTyping
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF0D3B73),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isTyping ? null : () => _sendMessage(),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BURBUJA DE MENSAJE
// ============================================================================
class _ChatBubble extends StatelessWidget {
  final PawBotMessage message;
  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final timeStr = DateFormat('HH:mm').format(message.timestamp);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: message.isError
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF0D3B73),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                message.isError
                    ? Icons.error_outline_rounded
                    : Icons.pets_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF0D3B73)
                    : (message.isError
                        ? const Color(0xFFFEF2F2)
                        : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: message.isError
                            ? const Color(0xFFFECACA)
                            : const Color(0xFFE2E8F0),
                      ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B2545).withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUser && message.sourceLabel != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: message.sourceLabel!.contains('Firestore')
                            ? const Color(0xFFECFDF5)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            message.sourceLabel!.contains('Firestore')
                                ? Icons.storage_rounded
                                : Icons.auto_awesome_rounded,
                            size: 12,
                            color: message.sourceLabel!.contains('Firestore')
                                ? const Color(0xFF15803D)
                                : const Color(0xFF1E5BB0),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              message.sourceLabel!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: message.sourceLabel!.contains('Firestore')
                                    ? const Color(0xFF15803D)
                                    : const Color(0xFF1E5BB0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _FormattedBotText(
                    text: message.text,
                    isUser: isUser,
                    isError: message.isError,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isUser
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D3B73),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.pets_rounded, color: Colors.white, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1E5BB0),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'PawBot está consultando...',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormattedBotText extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isError;

  const _FormattedBotText({
    required this.text,
    required this.isUser,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = isUser
        ? Colors.white
        : (isError ? const Color(0xFF991B1B) : const Color(0xFF1E293B));

    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isUser ? const Color(0xFF93C5FD) : const Color(0xFF0D3B73),
            ),
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          fontSize: 13.5,
          height: 1.45,
          color: baseColor,
          fontWeight: FontWeight.w500,
        ),
        children: spans,
      ),
    );
  }
}
