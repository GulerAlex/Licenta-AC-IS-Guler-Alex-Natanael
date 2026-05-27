# UniHub

Aplicatie Flutter pentru organizarea activitatii academice a studentilor.

## Functionalitati MVP

- autentificare si inregistrare
- configurare facultate, an de studiu si grupa
- materii pe semestre
- activitati de tip curs, seminar si laborator
- orar saptamanal si notite pe zile
- examene cu reminder
- note pe componente de evaluare
- ponderi si medii pe semestre
- profil academic cu statistici

## Cerinte

- Flutter SDK compatibil cu Dart `^3.9.2`
- proiect Supabase configurat
- schema academica rulata in Supabase SQL Editor:

```text
supabase_academic_schema_v2.sql
```

## Rulare locala

Aplicatia asteapta configurarea Supabase prin `--dart-define`:

```powershell
flutter run `
  --dart-define=SUPABASE_URL=URL_PROIECT `
  --dart-define=SUPABASE_ANON_KEY=CHEIE_ANON
```

## Verificari

```powershell
flutter analyze
flutter test
```

## Flow demo recomandat

1. Creeaza sau autentifica un cont demo.
2. Completeaza facultatea, anul de studiu si grupa.
3. Adauga 4-6 materii impartite intre Semestrul 1 si Semestrul 2.
4. Adauga cursuri, seminare sau laboratoare pentru cateva materii.
5. Verifica Orarul si pagina Astazi.
6. Adauga o notita pe o zi.
7. Adauga 1-2 examene cu reminder.
8. Introdu note pe componentele Examen, Seminar si Laborator.
9. Configureaza ponderile.
10. Verifica mediile si statisticile din Profil.
11. Testeaza logout/login si confirma ca datele raman salvate.
