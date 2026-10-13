<div align="center">

# Éveil

**Le Mac reste éveillé, le temps qu'il faut.**

[![Dernière version](https://img.shields.io/github/v/release/avialet/eveil?color=12A3B0&label=version)](https://github.com/avialet/eveil/releases/latest)
[![macOS 26](https://img.shields.io/badge/macOS-26%20Tahoe-F0A020)](#installation)
[![Licence MIT](https://img.shields.io/badge/licence-MIT-2E9D6E)](LICENSE)

[**Télécharger le DMG**](https://github.com/avialet/eveil/releases/latest) · [Site](https://eveil.vialet.app)

</div>

## Ce que fait Éveil

- **Un clic, une heure de fin.** 15 min, 1 h, 2 h, jusqu'à une heure précise ou sans fin : Éveil dit
  « éveillé jusqu'à 15 h 40 », puis le Mac retrouve ses réglages de veille.
- **Tant qu'il le faut.** Tant qu'un téléchargement avance, tant qu'une app tourne, tant que le Mac est
  sur secteur ; écran allumé, ou écran éteint et Mac éveillé.
- **Rester chez vous.** Aucun compte, aucun serveur, aucune télémétrie, aucun assistant administrateur.

## Installation

**Prérequis :** un Mac Apple Silicon sous macOS 26 (Tahoe) ou plus récent.

1. Téléchargez `Eveil-X.Y.Z.dmg` depuis la [dernière version](https://github.com/avialet/eveil/releases/latest).
2. Ouvrez le DMG et glissez **Éveil** dans **Applications**, puis double-cliquez.
3. Au premier lancement, macOS indique qu'il n'a pas pu vérifier l'app (elle est signée
   sans certificat Apple Developer). Cliquez **Terminé** (pas « Placer dans la corbeille »),
   ouvrez **Réglages Système › Confidentialité et sécurité**, descendez jusqu'à
   « Éveil a été bloqué… », cliquez **Ouvrir quand même**, authentifiez-vous, puis **Ouvrir**.
   Cette étape n'a lieu qu'une fois par téléchargement. Dans le Terminal :

   ```bash
   xattr -d com.apple.quarantine /Applications/Eveil.app
   ```

Pour vérifier le fichier téléchargé, comparez son empreinte avec celle publiée dans la même version :

```bash
shasum -a 256 -c Eveil-X.Y.Z.dmg.sha256
```

### Mises à jour

Éveil consulte une fois par jour la dernière version publiée sur GitHub. S'il en
existe une plus récente, un clic la télécharge, **vérifie son empreinte SHA-256**, contrôle
l'application qu'elle contient, la remplace et relance l'app. Si une étape échoue, l'app
installée n'est pas touchée. La recherche automatique se désactive dans **Réglages › Mises à jour**.

Le seul échange réseau de Éveil est cette lecture de la version publiée. Aucune donnée n'est envoyée.

## Notice

- **Un seul panneau**, dans l'icône de la barre des menus ou dans la fenêtre (Dock) : l'état, les durées,
  les conditions. Pendant une session : **Arrêter**, **+1 h** et l'interrupteur **Garder l'écran allumé**
  (allumé, l'écran ne s'éteint pas et ne se verrouille donc pas).
- **Icône** : soleil creux au repos, plein pendant une session. En mode Automatique, si l'app
  [Vialet](https://vialet.app) est installée, l'icône n'apparaît que pendant une session ; au repos,
  le menu de Vialet propose 1 h, Sans fin et Arrêter.
- **Liens** : `eveil://1h`, `eveil://2h`, `eveil://15min`, `eveil://sans-fin`, `eveil://telechargement`,
  `eveil://arreter`, et `eveil://` pour la fenêtre. Par exemple `open -g eveil://2h` dans un script.
- **Téléchargements** : Éveil regarde si un fichier partiel (`.download`, `.crdownload`, `.part`) grossit
  dans Téléchargements (et les dossiers ajoutés dans les Réglages) ; la session s'arrête après deux minutes
  sans progrès. macOS demande l'accès au dossier la première fois.
- **Batterie** : arrêt sous 10, 20 ou 30 % (20 % par défaut) et en mode Économie d'énergie, sur batterie,
  s'ils surviennent pendant une session.
- **Capot fermé** : fermer le capot met le Mac en veille, session ou non ; aucune app ne peut l'empêcher.
  Avec un écran externe et le chargeur branchés, le Mac continue capot fermé et Éveil le garde éveillé.
- **Raccourci global** facultatif (désactivé par défaut, ⌃⇧⌘Espace) : lance la dernière durée choisie, ou arrête.
- Fermer la fenêtre ne quitte pas l'app : la session continue. **⌘Q** quitte et arrête la session ;
  une mise à jour relance l'app et la session reprend.
- Pour vérifier : `pmset -g assertions | grep Eveil`.

### Vos données

Éveil ne garde que ses réglages et la session en cours, dans les préférences de l'app
(`defaults read fr.vialet.eveil`).

## Compiler depuis les sources

Il faut Swift 6.3 ou plus récent (les Command Line Tools suffisent, Xcode n'est pas nécessaire).

```bash
git clone https://github.com/avialet/eveil.git
cd eveil
make test      # tests du noyau
make run       # construit et lance l'app
make install   # installe dans /Applications
make release   # fabrique build/Eveil-X.Y.Z.dmg et son empreinte
```

L'icône et l'habillage du DMG viennent de l’outillage commun des apps vialet.app
(`scripts/plaque.swift`), cloné à côté de l'app (sinon `VIALETAPPS_PATH=<chemin>`) :

```bash
make icon         # icône : plaque aux teintes de App/Brand.swift, son glyphe (initiale s'il est vide)
make dmg-layout   # fond et disposition de la fenêtre du DMG, dans scripts/dmg (à committer)
```

| Dossier | Contenu |
|---|---|
| `Packages/EveilCore` | Noyau sans interface ni dépendance : sessions, heure de fin, conditions, textes d'état, reprise |
| `Eveil` | L'application SwiftUI ; `App/Brand.swift` porte son identité |
| `scripts` | Assemblage de l'app et du DMG ; `scripts/dmg` : fond et disposition de sa fenêtre |
| `docs` | [Publier une version](docs/publier-une-version.md), [tests](docs/tests.md), notes de version |

Le socle commun (mises à jour, thème, raccourci global, panneau flottant) vient de
[VialetKit](https://github.com/avialet/vialetkit). Publier une version ne demande que de
modifier `VERSION` puis de pousser un tag `vX.Y.Z` : la CI construit et publie le DMG, et
les utilisateurs reçoivent la mise à jour dans l'app.

## Confidentialité

Éveil ne collecte rien. Vos données ne quittent jamais votre Mac. La seule requête
réseau est la lecture de la dernière version publiée sur GitHub, que vous pouvez désactiver.

## Licence

[MIT](LICENSE) © 2026 Aurélien Vialet
