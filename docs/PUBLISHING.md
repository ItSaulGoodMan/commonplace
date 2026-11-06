# Objava na Google Play

Ovo je uputstvo za objavu Play verzije Commonplace-a: prijava preko Googlea, bilješke pravi server, i Commonplace Plus pretplata. Nazivi u konzolama ostavljeni su na engleskom, kako ih vidiš na ekranu.

## Šta košta

| Stvar | Cijena |
|---|---|
| Google Play developer nalog | već ga imaš |
| Google Cloud projekat za prijavu i Play API | 0, bez kartice |
| Cloudflare (server) | 0, besplatni plan, bez kartice |
| Gemini besplatni ključ | 0, ako na tom projektu **nikad ne uključiš billing** |
| Gemini plaćeni ključ za Plus | po potrošnji, otprilike 1 do 5 centi po bilješci; tek kad imaš pretplatnika, i nije obavezan |
| Google Play provizija | 15% od pretplata |

## 1. Google Cloud: prijava preko Googlea (besplatno)

1. Na [console.cloud.google.com](https://console.cloud.google.com) napravi projekat, npr. `commonplace`. Billing ne uključuj.
2. **APIs & Services → OAuth consent screen**: User type **External**. Upiši ime aplikacije, email za podršku i scope-ove `openid`, `email`, `profile`, pa klikni **Publish app**. Za ove osnovne scope-ove Google ne traži verifikaciju.
3. **Credentials → Create credentials → OAuth client ID**:
   - **Web application**, ime `commonplace-server`. Njegov **Client ID** ide na dva mjesta: u `server/wrangler.jsonc` kao `GOOGLE_CLIENT_IDS` i u build aplikacije kao `GOOGLE_SERVER_CLIENT_ID`.
   - **Android**: package `com.nemanjapejic.commonplace` i SHA-1 otisak. Napravi po jedan klijent za svaki ključ kojim je aplikacija potpisana: upload ključ (korak 3) i Play App Signing ključ (Play Console → **Test and release → App integrity**). Bez ovoga Google prijava na telefonu ne radi.
4. **APIs & Services → Library**: uključi **Google Play Android Developer API**. Server ga treba za provjeru kupovina.

## 2. Gemini besplatni ključ

1. Na [aistudio.google.com/apikey](https://aistudio.google.com/apikey) napravi ključ u **posebnom** projektu (npr. `commonplace-free`) i na njemu **nikad ne uključuj billing**. Tako ne može koštati ništa: kad se dnevni limit potroši, bilješke čekaju sutra.
2. Uslovi Googlea za besplatni ključ:
   - aplikacija se **ne smije nuditi u EU, Islandu, Lihtenštajnu, Norveškoj, Švicarskoj i Velikoj Britaniji** (korak 5);
   - korisnici moraju imati **18+**;
   - Google smije koristiti poslane snimke za svoje proizvode, i to piše u aplikaciji.

## 3. Server na Cloudflareu

Treba ti Node 22 ili noviji. Sve je opisano u [server/README.md](../server/README.md), ukratko:

```bash
cd server
npm install
npx wrangler login
npx wrangler d1 create commonplace          # database_id upiši u wrangler.jsonc
npx wrangler d1 migrations apply commonplace --remote
npx wrangler secret put GEMINI_API_KEY      # ključ iz koraka 2
npx wrangler secret put SESSION_SECRET      # 48+ nasumičnih znakova
npx wrangler secret put ADMIN_TOKEN         # 32+ nasumičnih znakova, za brojke
npx wrangler deploy
```

`deploy` ispiše adresu, npr. `https://commonplace-api.tvojnalog.workers.dev`. To je `API_BASE_URL` aplikacije. Ako `GOOGLE_CLIENT_IDS` promijeniš u `wrangler.jsonc`, ponovo pokreni `npx wrangler deploy`.

Brojke (korisnici, bilješke, potrošnja plaćenog ključa, da li se besplatni ključ potrošio) dobiješ ovako:

```bash
curl -H "Authorization: Bearer TVOJ_ADMIN_TOKEN" https://commonplace-api.tvojnalog.workers.dev/v1/admin/stats
```

## 4. Ključ za potpisivanje i build

Upload ključ napraviš jednom i čuvaš ga zauvijek. Ako ga izgubiš, ključ se mora mijenjati preko Google podrške.

```bash
keytool -genkey -v -keystore ~/commonplace-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Napravi `android/key.properties`. Ovaj fajl se nikad ne commituje; `.gitignore` ga već preskače.

```properties
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/Users/Ti/commonplace-upload.jks
```

SHA-1 upload ključa (za korak 1.3):

```bash
keytool -list -v -keystore ~/commonplace-upload.jks -alias upload
```

Build za Play:

```bash
flutter build appbundle --release --flavor play \
  --dart-define=API_BASE_URL=https://commonplace-api.tvojnalog.workers.dev \
  --dart-define=GOOGLE_SERVER_CLIENT_ID=1234-abc.apps.googleusercontent.com \
  --dart-define=SUPPORT_EMAIL=podrska@tvojdomen.com
```

Fajl je `build/app/outputs/bundle/playRelease/app-play-release.aab`. Pri svakoj novoj verziji povećaj `version:` u `pubspec.yaml`, npr. `0.1.0+2`.

## 5. Play Console

1. **Create app**: ime `Commonplace`, App, Free (pretplata se plaća unutar aplikacije).
2. **Monetize → Products → Subscriptions → Create subscription**:
   - Product ID tačno `commonplace_plus`;
   - base plan **Monthly** sa cijenom, npr. 2,99 USD (Play preračuna za druge zemlje);
   - aktiviraj ga.
3. **Countries / regions** (Production i testni trackovi): izbaci sve zemlje EU (Austrija, Belgija, Bugarska, Hrvatska, Kipar, Češka, Danska, Estonija, Finska, Francuska, Njemačka, Grčka, Mađarska, Irska, Italija, Latvija, Litvanija, Luksemburg, Malta, Holandija, Poljska, Portugal, Rumunija, Slovačka, Slovenija, Španija, Švedska), plus Island, Lihtenštajn, Norvešku, Švicarsku i Veliku Britaniju. To traže Googleovi uslovi za besplatni Gemini ključ. Kad server pređe na plaćeni ključ za sve, mogu se dodati.
4. **App content**:
   - **Privacy policy**: objavi [privacy-policy.md](privacy-policy.md) negdje javno (besplatno preko GitHub Pages ili Google Sites), popuni email i daj link.
   - **Target audience**: samo 18+.
   - **Content rating**: popuni upitnik (nema nasilja, kockanja, korisničke komunikacije).
   - **Data safety**:
     - prikuplja se **email i ime** (upravljanje nalogom);
     - **fotografije i video** se šalju na obradu, za funkcionalnost aplikacije, i dijele se s Googleom (Gemini ih obrađuje i na besplatnom ključu ih smije koristiti za svoje proizvode);
     - **istorija kupovina** (Plus);
     - sve ide šifrovano (HTTPS);
     - korisnik može obrisati nalog.
   - **Account deletion**: aplikacija ima Settings → Delete account. Play traži i web link, pa u politiku privatnosti upiši kako se traži brisanje (npr. email) i daj taj link.
   - **AI-generated content**: u aplikaciji je „Report a problem with this note“ (meni bilješke), a šalje na `SUPPORT_EMAIL`.
5. **Testing → Closed testing**: ako je tvoj developer nalog **lični i otvoren poslije novembra 2023.**, Google traži bar **12 testera kroz 14 dana** prije javne objave. Dodaj njihove Gmail adrese, a oni instaliraju preko linka iz konzole.

## 6. Play API pristup za server (provjera pretplata)

1. Play Console → **Setup → API access** (ili **Users and permissions**): poveži Google Cloud projekat iz koraka 1.
2. U Google Cloudu: **IAM & Admin → Service accounts → Create**, npr. `play-verifier`. Uloge u Cloudu ne trebaju. **Keys → Add key → JSON** preuzme fajl.
3. Play Console → **Users and permissions → Invite new users**: email tog service accounta, s dozvolama **View financial data** i **Manage orders and subscriptions**, za ovu aplikaciju.
4. `npx wrangler secret put PLAY_SERVICE_ACCOUNT < preuzeti-fajl.json`, pa obriši fajl s računara.

Probaj kupovinu s test nalogom (Play Console → **Settings → License testing**: dodaj svoj Gmail). Test kupovine se ne naplaćuju.

## 7. Kad dođu pretplatnici (kasnije)

Dok postoji samo besplatni ključ, i Plus korisnici dijele Googleov besplatni dnevni limit (samo dobiju veći lični limit). Kad pretplate počnu donositi novac:

1. U AI Studiju napravi ključ u projektu **s** billingom (npr. `commonplace-paid`) i postavi budžet i upozorenje u Cloud Billingu.
2. `npx wrangler secret put GEMINI_PAID_API_KEY`.

Od tada pretplatnici idu preko tog ključa, bez zajedničkog limita. Besplatni korisnici i dalje idu preko besplatnog ključa i **nikad ne koštaju ništa**.

**Svaki pretplatnik ostaje u plusu.** Server mjeri stvarni trošak svakog zahtjeva (Gemini sam javlja broj tokena) i vodi ga po pretplatniku za tekući mjesec. Kad pretplatnik dođe do `PLUS_MONTHLY_BUDGET_USD` (podrazumijevano 1 $), do kraja mjeseca ide preko besplatnog ključa. Tako ni jedan pretplatnik ne može koštati više od 1 $ mjesečno, a donosi oko 2,54 $ (2,99 $ minus 15% Googlea). Jedna bilješka na Flash-Liteu košta oko 0,25–0,4 centa, pa 1 $ pokriva oko 250–400 bilješki mjesečno, što je više nego što skoro iko napravi.

Šta podesiti u `wrangler.jsonc` (poslije svake izmjene ide `npx wrangler deploy`):
- `PLUS_MONTHLY_BUDGET_USD`: drži ga ispod oko 40% najniže cijene pretplate koju postaviš u Playu (i za druge zemlje);
- `PAID_PRICE_INPUT_PER_M`, `PAID_PRICE_AUDIO_PER_M`, `PAID_PRICE_OUTPUT_PER_M`: cijene modela sa [cjenovnika](https://aistudio.google.com/docs/pricing). Ažuriraj ih ako Google promijeni cijene ili ako promijeniš `GEMINI_PAID_MODEL`;
- `GEMINI_PAID_MODEL` i `GEMINI_PAID_THINKING`: Flash-Lite i `MINIMAL` su najjeftiniji. Flash je oko 4 puta skuplji, i za njega razmišljanje mora biti `LOW`;
- `FREE_NOTES_PER_DAY`, `PLUS_NOTES_PER_DAY`: dnevni limiti.

Ne nudi besplatni probni period za Plus u Play konzoli: probni korisnik troši plaćeni ključ, a ništa ne plaća. Besplatne bilješke svaki dan su već proba.
