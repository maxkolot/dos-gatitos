# Dos Gatitos 🐈🐈‍⬛

Браузерная игра про двух котиков. Живая версия: https://maxkolot.github.io/dos-gatitos/

## Для ботов (@ИБИ)

- Код лежит на сервере «Котик Колот» в `/home/platina/projects/dos-gatitos` — правь файлы через shell / write_file.
- Публикация: инструмент `repo_publish` (repo `dos-gatitos`, message — что изменил). Он делает commit + push, GitHub Actions
  сам собирает и выкладывает игру на Pages; инструмент возвращает ссылку на прогон и на игру. Статус — `repo_status`.
- Сам `git push` из shell не сработает — ключ есть только у сервера, это нормально.
- Без сборки: `index.html` в корне + свои js/css/картинки. Со сборкой (Vite и т.п.): `package.json` со скриптом `build`,
  результат в `dist/` (для Vite поставь `base: './'`).
- Все пути относительные (`./game.js`, не `/game.js`) — игра живёт по адресу `/dos-gatitos/`.
