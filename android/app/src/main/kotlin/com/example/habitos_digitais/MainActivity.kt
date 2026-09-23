package com.example.habitos_digitais

import android.app.KeyguardManager
import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * RNF01: bloquear o celular nao pode contar como abandonar a sessao.
 *
 * O Android emite `paused` tanto quando o usuario sai do app quanto quando a
 * tela apaga — os dois casos sao indistinguiveis do lado Dart. Este canal
 * devolve o que os separa: com a tela desligada, o `paused` veio do botao de
 * energia (ou do timeout), e e justamente o comportamento que o app quer
 * incentivar.
 */
class MainActivity : FlutterActivity() {

    private companion object {
        const val CANAL = "habitos_digitais/tela"
        const val METODO = "estadoDaTela"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL)
            .setMethodCallHandler { chamada, resposta ->
                if (chamada.method != METODO) {
                    resposta.notImplemented()
                    return@setMethodCallHandler
                }

                val energia = getSystemService(Context.POWER_SERVICE) as PowerManager
                val bloqueio =
                    getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager

                // Os dois valores crus, sem decidir nada aqui: a regra de
                // negocio mora no Dart, e no S23 ainda precisamos ver se ha
                // corrida entre o apagar da tela e o onPause.
                resposta.success(
                    mapOf(
                        "isInteractive" to energia.isInteractive,
                        "isKeyguardLocked" to bloqueio.isKeyguardLocked,
                    )
                )
            }
    }
}
