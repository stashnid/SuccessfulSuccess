# Лабораторна: налаштування входу

## Що вже підготовлено в коді

- `/` — публічна сторінка із кнопкою Sign in.
- `/login/` — починає authorization code + PKCE через `react-oidc-context` / `oidc-client-ts`.
- `/auth/callback/` — завершує вхід і повертає на `/today/`.
- Email видно у шапці; Sign out очищує локальну сесію і відкриває Cognito logout.
- API отримує access token; ID token використовується лише для синхронізації профілю.
- `infra/auth.yml` містить Essentials, self sign-up, Managed Login v2 та branding.

Auth stack `successfulsuccess-auth` створений 2026-10-07 у `us-east-1`.
`/login/` на живому сайті відкриває Cognito Managed Login з полями email і пароль,
посиланням реєстрації та кнопкою Google. Користувач перевірив реальний вхід
через Google і побачив свій email на `/today/`. Вихід із Cognito перевірено
в браузері після виправлення гонки з автоматичним повторним входом.
Вхід із паролем ще потрібно перевірити.
Повторне розгортання статичного сайту: `make deploy-frontend`. Ця команда читає
публічні Cognito outputs зі стека, збирає frontend, завантажує файли в приватне
S3-сховище та оновлює CloudFront. Коли backend буде доступний, передай
`PUBLIC_API_URL=https://...` у цю команду; зараз API онлайн ще немає.

## Твої дії: Google Cloud

1. Відкрити https://console.cloud.google.com/ і ввійти власним Google-акаунтом.
2. Вибір проєкту у верхній панелі → New project → назва SuccessfulSuccess → Create.
3. Вибрати створений проєкт; через пошук відкрити Google Auth Platform.
4. Get started: назва застосунку, власний support email, Audience External, контактний email.
5. Залишити тільки basic identity scopes: openid, email, profile.
6. Після підтвердження Cognito-домену: Clients → Create client → Web application.
7. Authorized JavaScript origin: `https://<cognito-domain>`.
8. Authorized redirect URI: `https://<cognito-domain>/oauth2/idpresponse`.
9. Client ID і Client Secret записати у локальний gitignored `.env` як GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET; секрет у чат не надсилати.
10. Audience → Publish app; для здачі перевірити статус In production.

Домен Cognito беремо з фактичного auth stack output HostedDomain.
Для нового стеку поточний шаблон формує prefix як `${ProjectName}-${AWS::AccountId}`.
Не створюємо OAuth client із непідтвердженим доменом і не змінюємо наявний prefix навмання.

## Контракт адрес Cognito

Параметр CallbackUrls у шаблоні — адреси повернення після входу:

- `http://localhost:3000/auth/callback/` (або реальний локальний порт).
- `https://d3j8i4re8dhmr8.cloudfront.net/auth/callback/` для поточної distribution.
- Callback власного домену після його підключення.

Параметр AppUrls — адреси повернення після виходу:

- `http://localhost:3000/`.
- `https://d3j8i4re8dhmr8.cloudfront.net/`.
- Головна власного домену після його підключення.

Реєструємо лише власні адреси. Callback/logout URL повинні точно збігатися,
включно зі схемою, портом, шляхом і завершальним `/`.
До старого callback на `/` нова інтеграція не повертається.

## Локальний запуск

Docker Compose передає фронтенду Cognito-змінні з кореневого `.env`:
COGNITO_USER_POOL_ID, COGNITO_CLIENT_ID, COGNITO_DOMAIN.
Після отримання реальних значень запускаємо `docker compose up --build`.
Локальний Cognito також є AWS-сервісом: справжній login потребує auth stack та інтернету,
навіть якщо frontend/backend/PostgreSQL запущені на ноутбуці.

Для запуску фронтенду без Docker: `npm run dev` у frontend; змінні NEXT_PUBLIC_*
задаємо у gitignored frontend/.env.local за зразком auth.env.example.
Google secret ніколи не має префікса NEXT_PUBLIC_ і не потрапляє на фронтенд.

## Що ще потрібно до здачі

- Auth stack, Google-провайдер, callback/logout URLs і frontend вже розгорнуто.
  `cfn-lint` та локальні `infra/auth.guard` правила пройшли; CloudFormation
  change set `lab3-auth-20261007-initial` не мав помилок валідації та створив
  лише п'ять Cognito-ресурсів.
- `make deploy-frontend` автоматично бере публічні auth Outputs зі стека,
  збирає сайт і публікує його в S3/CloudFront. Першу збірку з Cognito вже
  опубліковано; `/login/` відкриває реальну сторінку Cognito.
- Старі ECS targets у Makefile ще потребують узгодження з реальною
  інфраструктурою; вони не розгортають auth stack.
- Попередній ECS stack має `CREATE_FAILED`. Ціль ALB стала `healthy` після
  виправлення health check на `/health`, але сайт ще не має HTTPS-маршруту до
  API, а task definition не передає Cognito pool/client IDs. Тому зустрічі та
  синхронізація профілю онлайн поки недоступні.
- Перевірити refresh, 401 та password sign-up/sign-in; Google sign-in і logout
  вже перевірені окремо.
- Два скриншоти з email у шапці, URL `/login/`, коміт та доступ викладача до репозиторію.
- Підключити власний домен для виконання відповідної вимоги здачі.

CloudFormation schema validation (cfn-lint), security checks (cfn-guard) і
account-aware change set мають виконуватися до деплою. Вони не замінюються
перевіркою синтаксису YAML або успішною frontend-збіркою.
