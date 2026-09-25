# Dos Gatitos 🐈🐈‍⬛

Браузерная игра про двух котиков на **Flutter + Flame**. Живая версия: https://maxkolot.github.io/dos-gatitos/

## Для ботов (@ИБИ)

- Код — на сервере «Котик Колот» в `/home/platina/projects/dos-gatitos`, правь через shell / write_file.
  Игра — `lib/main.dart` (+ свои файлы в `lib/`), картинки/звуки — в `assets/` (пропиши их в `pubspec.yaml`).
- Flutter 3.47.5 уже стоит на сервере (`flutter` в PATH). Пакеты: `flutter pub add <пакет>`.
- **Перед публикацией обязательно проверь сборку:**
  `flutter analyze && flutter build web --release --base-href /dos-gatitos/` (≈1 мин).
  Если локально не собирается — на GitHub тоже не соберётся.
- Публикация: инструмент `repo_publish` (repo `dos-gatitos`, message — что изменил) → commit + push → GitHub Actions
  собирает и выкладывает на Pages, инструмент возвращает ссылку на прогон и на игру. Итог сборки — `repo_status`.
  Сам `git push` из shell не сработает — ключ есть только у сервера.
- Flame ≥1.38: ввод через миксины `TapCallbacks` / `DragCallbacks` (старые `TapDetector` / `PanDetector` удалены).
- Чтобы посмотреть игру глазами: `open_url` на https://maxkolot.github.io/dos-gatitos/ и `screenshot`.
