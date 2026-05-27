# UniHub MVP Status

## Stare curenta

Aplicatia este in forma MVP testabila pentru fluxul principal de student:

- autentificare si inregistrare
- configurare initiala facultate, an de studiu si grupa
- profil academic editabil
- materii pe semestre
- ascundere semestru din Orar si Astazi
- activitati de tip curs, seminar si laborator
- orar saptamanal
- notite pe zile
- examene/evenimente academice cu reminder
- preferinte notificari
- note pe componente de evaluare
- ponderi pe componente
- medii pe Semestrul 1, Semestrul 2 si media anuala
- profil cu statistici academice
- empty states polish pentru Astazi, Orar, Materii si Note

## Ultimele verificari tehnice

Ultimele verificari rulate au trecut:

```powershell
flutter analyze
flutter test
```

Au fost verificate manual fluxurile sensibile:

- login/signup
- configurare facultate, an de studiu si grupa
- adaugare materie
- adaugare activitate
- adaugare examen
- editare profil

README-ul proiectului a fost actualizat cu instructiuni de rulare si flow demo pentru licenta.

Repository-ul a fost impins pe GitHub dupa modificarile MVP.

## Supabase

Pentru ca ecranele Materii, Orar, Note si Astazi sa functioneze, trebuie rulat in Supabase SQL Editor:

```text
supabase_academic_schema_v2.sql
```

Scriptul este gandit sa fie non-distructiv pentru datele existente:

- foloseste `create table if not exists`
- foloseste `add column if not exists`
- recreeaza politicile RLS cu `drop policy if exists`, fara sa stearga tabele sau date

Daca apare avertismentul Supabase "Potential issue detected", este normal pentru ca scriptul contine `drop policy if exists`.

## Flow demo recomandat

Pentru prezentare sau test final:

1. Creeaza/intra intr-un cont demo.
2. Completeaza facultatea, anul de studiu si grupa.
3. Adauga 4-6 materii impartite intre Semestrul 1 si Semestrul 2.
4. Pentru cateva materii, adauga curs/seminar/laborator.
5. Verifica Orarul.
6. Adauga o notita pe o zi.
7. Adauga 1-2 examene cu data, ora si reminder.
8. Verifica pagina Astazi.
9. Adauga note la componentele Examen/Seminar/Laborator.
10. Configureaza ponderi.
11. Verifica mediile pe semestre si media anuala.
12. Verifica profilul academic si statisticile.
13. Testeaza logout/login si confirma ca datele raman salvate.

## Ce mai merita facut

Prioritate mare:

- verificare notificari pe device real
- creare cont demo curat pentru licenta

Prioritate medie:

- capturi ecran curate pentru documentatie
- verificare build APK final
- verificare daca mai exista texte in engleza in UI

Nu recomand momentan:

- schimbari mari de baza de date
- feature-uri sociale/chat/AI
- redesign complet
- adaugare de module mari inainte de stabilizarea MVP-ului

## Cum se continua dupa restart

Dupa restart sau intr-o sesiune noua, spune:

```text
continua din MVP_STATUS.md
```

Primul lucru recomandat este:

```powershell
git status --short
flutter analyze
flutter test
```

Daca totul este verde, continua cu testarea pe emulator/telefon.
