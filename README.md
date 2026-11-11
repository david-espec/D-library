# D Libery — biblioteca digital pessoal

App Android em **Flutter** para pesquisar livros, fotografar capas, organizar sua
estante e acompanhar suas leituras. Seus dados ficam no próprio celular.

**Baixar o APK:** https://github.com/david-espec/D-library/releases/download/apk/D-Libery.apk
(no celular, toque no arquivo para instalar; permita "instalar apps desta fonte" se pedir).

## Funcionalidades

- **Pesquisa** no Google Books e no Open Library ao mesmo tempo, por tudo, título,
  autor, ISBN, editora ou categoria. Resultados repetidos são juntados.
- **Câmera**: lê o **código de barras ISBN** ao vivo; ou fotografe a **capa** e o
  texto é lido com o **Google ML Kit** (no aparelho, sem enviar a foto) e pesquisado.
  Se não achar, cadastre manualmente usando a foto como capa.
- **Estante** em prateleiras: Todos, Favoritos, Quero ler, Lendo, Lidos,
  Abandonados e Adicionados manualmente; ordenação e filtro por gênero.
- **Leitura**: status, datas de início e fim, páginas lidas (com histórico),
  avaliação com meia estrela, anotações.
- **Detalhes**: capa, sinopse, editora, ano, páginas, ISBN, idioma e links — "ler
  grátis" só para versões legais (domínio público, Internet Archive, empréstimo
  no Open Library), além de prévia, compra e sebos.
- **Estatísticas**: meta anual, livros e páginas por mês, gêneros e autores.
- **Perfil**: nome e foto, tema claro/escuro/automático, chave opcional do Google
  Books, backup (compartilhar arquivo) e restauração.

## Tecnologias

| Parte | Pacote |
| --- | --- |
| Interface | Flutter 3.47 (Material 3), fontes Inter e Cormorant Garamond embutidas |
| Estado | `provider` |
| Banco de dados | `sqflite` (livros) + arquivos JPG (capas) |
| APIs | `http` → Google Books e Open Library |
| Código de barras | `mobile_scanner` (ML Kit) |
| Texto da capa | `google_mlkit_text_recognition` |
| Fotos | `image_picker` |
| Links, backup | `url_launcher`, `share_plus`, `file_picker`, `shared_preferences` |

## Estrutura

```
lib/
  main.dart               app, temas e tela inicial
  models/book.dart        Book, SearchResult, links, status
  services/               APIs de livros, ISBN, OCR, SQLite/capas, estatísticas
  state/app_state.dart    estante, regras de leitura, configurações, backup
  ui/theme.dart           cores (claro/escuro) no estilo do mockup
  ui/widgets/             capa, estante, estrelas, cartões
  ui/screens/             início, estante, pesquisa, resultado, livro, formulário,
                          câmera, estatísticas, perfil, boas-vindas
test/                     testes da lógica (ISBN, APIs, OCR, regras, estatísticas)
```

## Desenvolvimento

```bash
flutter pub get
flutter test
flutter run            # com um celular Android conectado
flutter build apk      # gera build/app/outputs/flutter-apk/app-release.apk
```

A cada push no `main`, o GitHub Actions roda a análise e os testes, compila o APK e
o publica na release `apk` (link acima).

**Assinatura:** para o APK sempre instalar por cima da versão anterior, crie os
segredos `DLIBERY_KEYSTORE_BASE64` e `DLIBERY_KEYSTORE_PASSWORD`. Sem eles, o
workflow usa uma chave guardada no cache do Actions.

A versão web anterior (React/PWA) está no branch `web-react`.
