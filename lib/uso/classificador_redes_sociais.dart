/// Classificação de "rede social" para o RF04.
///
/// ESCOLHA METODOLÓGICA DOCUMENTADA, NÃO EXAUSTIVA. Esta lista não é um fato
/// técnico nem uma taxonomia oficial: é um recorte definido pelo autor e que
/// precisa ser declarado como tal no artigo, junto do critério abaixo.
///
/// CRITÉRIO DECLARADO: aplicativos cuja função primária é o consumo de feed
/// social com curadoria algorítmica e rolagem sem fim.
///
/// EXCLUÍDOS deliberadamente, com o motivo — a exclusão é tão metodológica
/// quanto a inclusão, e omiti-la enviesaria a leitura dos dados:
///
///   com.google.android.youtube  uso misto: aula, tutorial
///   com.whatsapp                comunicação direta, sem feed
///   org.telegram.messenger      comunicação direta, sem feed
///   com.linkedin.android        feed algorítmico, mas uso profissional
///
/// Package name errado não gera erro: soma zero em silêncio. Por isso o
/// ServicoUso registra quais destes foram efetivamente encontrados no dia.
library;

abstract final class ClassificadorRedesSociais {
  /// Set, não List: a checagem roda contra todos os apps usados no dia.
  static const Set<String> packages = {
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.twitter.android',
    'com.facebook.katana',
    'com.snapchat.android',
    'com.reddit.frontpage',
    'com.pinterest',
    'tv.twitch.android.app',
  };

  static bool eRedeSocial(String packageName) => packages.contains(packageName);
}
