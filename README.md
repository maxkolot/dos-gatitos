# Dos Gatitos 🐈🐈‍⬛

Игра про двух котиков на **Flutter + Flame**. Живая версия: https://maxkolot.github.io/dos-gatitos/

**Установить на iPhone:** открыть ссылку в Safari → «Поделиться» → «На экран Домой». Обновления приходят сами:
при каждом запуске грузится свежая версия, а если игра была открыта — снизу появится кнопка «Nueva versión».

## Для ботов (@ИБИ): до 8 ролей параллельно

1. `repo_workspace {repo: "dos-gatitos", role_id}` — ТВОЯ копия репозитория (`/home/platina/projects/dos-gatitos/<роль>`).
   Работай только в ней; чужие папки не трогай.
2. Перед задачей — `git pull`. Коммить маленькими шагами (`git add -A && git commit -m ...`).
3. **Своя фича — свой файл:** `lib/features/<фича>.dart` (один Component). Подключение — одна строка import и одна строка
   в списке `lib/features/features.dart` (этот файл сливается построчно, параллельные добавления не конфликтуют).
   `lib/game.dart`, `lib/cats.dart`, `pubspec.yaml` — общие: меняй минимально и только если без этого никак.
4. Проверка: `flutter analyze` (Flutter 3.47.5 на сервере). Полную сборку делает очередь.
5. `repo_publish {repo, role_id, message}` — очередь слияния: rebase на свежий main → сборка → push → GitHub Actions
   выкладывает на Pages. Конфликт или ошибка сборки — в main ничего не попадёт, инструмент вернёт файлы/ошибки:
   `git pull`, поправь (сохрани и свою, и чужую логику), `git add`, `git rebase --continue`, `repo_publish` снова.
6. `repo_status {repo, role_id}` — твоя копия, очередь, итоги публикаций, выкладки. `git push` не нужен и не сработает.

- Flame ≥1.38: ввод — миксины `TapCallbacks` / `DragCallbacks`; доступ к игре — `HasGameReference<DosGatitosGame>`.
- Картинки/звуки — в `assets/` (+ прописать в `pubspec.yaml`), пути относительные.
- Посмотреть игру глазами: `open_url` https://maxkolot.github.io/dos-gatitos/ + `screenshot`.

## Иконка — одной командой

Единственный источник — `web/icon.png` (1024×1024), все размеры делаются при выкладке.

```bash
python3 tool/icon.py --emoji "🦁" --bg "#FF8FB1"   # эмодзи на цветном фоне
python3 tool/icon.py --svg my_icon.svg               # нарисованный SVG
python3 tool/icon.py --image https://example.com/cat.png
```

Потом `repo_publish`. На iPhone новая иконка появится после переустановки ярлыка
(удалить с экрана «Домой» и снова «На экран Домой») — iOS запоминает иконку при установке.

## Название — одна правка

`app.json`: `name` (в игре и во вкладке), `short_name` (подпись под иконкой на iPhone, до ~12 символов),
`subtitle` (строка под названием в игре). Больше нигде менять не нужно — выкладка подставит его сама. Потом `repo_publish`.
