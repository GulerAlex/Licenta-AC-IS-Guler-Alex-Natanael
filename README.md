# UniHub

UniHub este o aplicatie mobila Flutter pentru organizarea activitatii academice a studentilor. Aplicatia centralizeaza materiile, orarul, examenele, notitele, notele si progresul academic intr-un singur flux.

## Scopul aplicatiei

Aplicatia este gandita pentru studenti care au nevoie de o evidenta clara a activitatilor academice:

- ce materii au in fiecare semestru
- cand au cursuri, seminare si laboratoare
- ce examene sau deadline-uri urmeaza
- ce note au pe componente de evaluare
- cum evolueaza media, creditele si statutul academic

## Functionalitati principale

- autentificare si inregistrare cu Supabase Auth
- configurare profil academic: facultate, an de studiu si grupa
- administrare materii pe Semestrul 1 si Semestrul 2
- activitati de tip curs, seminar si laborator
- orar saptamanal cu vizibilitate pe semestre
- notite pe zile in calendar
- examene/evenimente academice cu reminder
- preferinte pentru notificari
- note pe componente de evaluare
- ponderi pentru componentele de nota
- calcul medii pe semestre si medie anuala
- profil academic cu statistici si remindere
- export/copie raport academic in format text

## Tehnologii folosite

- Flutter / Dart
- Supabase Auth
- Supabase PostgreSQL
- Supabase Realtime
- Row Level Security pentru izolarea datelor pe utilizator
- `flutter_local_notifications` pentru notificari locale
- `shared_preferences` pentru preferinte locale
- `table_calendar` pentru calendar

## Structura proiectului

```text
lib/
  data/              acces la Supabase si preferinte locale
  models/            modele pentru materii, orar, note, profil si progres
  screens/
    functionality/   logica ecranelor
    ui/              componente vizuale
  services/          notificari si calcul progres academic
  supabase/          configurare Supabase
test/                teste pentru modele si calcul academic
```

## Configurare Supabase

Aplicatia foloseste schema SQL din:

```text
supabase_academic_schema_v2.sql
```

Scriptul trebuie rulat in Supabase SQL Editor inainte de testarea fluxurilor academice. El creeaza tabelele pentru materii, activitati, evenimente, note, task-uri si notite, impreuna cu politicile RLS necesare.

Configurarea Supabase se face prin `--dart-define`:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=URL_PROIECT `
  --dart-define=SUPABASE_ANON_KEY=CHEIE_ANON
```

Pentru dezvoltare locala exista valori implicite in `lib/supabase/supabase_config.dart`.

## Rulare pe telefon Android

Conecteaza telefonul prin USB, activeaza USB debugging si verifica device-ul:

```powershell
flutter devices
```

Ruleaza aplicatia pe device-ul ales:

```powershell
flutter run -d DEVICE_ID
```

Exemplu:

```powershell
flutter run -d R3GYA01VB2T
```

## Verificari tehnice

```powershell
flutter analyze
flutter test
```

Pentru generarea unui APK:

```powershell
flutter build apk
```

## Flow recomandat de testare

1. Creeaza sau autentifica un cont demo.
2. Completeaza facultatea, anul de studiu si grupa.
3. Adauga materii in Semestrul 1 si Semestrul 2.
4. Adauga activitati pentru cateva materii: curs, seminar, laborator.
5. Verifica pagina Orar si pagina Astazi.
6. Adauga o notita pe o zi din calendar.
7. Adauga examene sau evenimente academice cu reminder.
8. Introdu note pentru componentele de evaluare.
9. Configureaza ponderile.
10. Verifica mediile, creditele si statisticile din Profil.
11. Copiaza raportul academic din Profil.
12. Testeaza logout/login si confirma persistenta datelor.

## Observatii

Aplicatia a fost testata pe emulator si pe telefon Android real. Pentru un demo stabil se recomanda folosirea unui cont demo curat, populat cu materii, activitati, note si examene reprezentative.
