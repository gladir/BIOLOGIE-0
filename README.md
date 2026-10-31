# BIOLOGIE-0
Suite de commande écrit en Turbo Pascal/Free Pascal pour la biologie

## CS3DA - Circulatory System 3D Anatomy

Clone graphique (VGA 640x480, 16 couleurs) de l'application *Circulatory System 3D
Anatomy* pour le réseau sanguin : `CS3DA.PAS` (Turbo Pascal 7 / Free Pascal).
Le programme est autonome : un seul fichier source, aucun fichier d'inclusion et
seulement les unités `DOS`, `Crt`, `Graph` (ou `PtcGraph`, `PtcCrt`, `PtcMouse` avec Free Pascal).

Les données se trouvent dans `SAMPLES/CS3DA` :

| Fichier       | Contenu |
|---------------|---------|
| `HUMAN.C3D`   | Géométrie 3D : structures (`STRUCT`), sommets (`V`), faces (`F`) pour le coeur, les poumons et la silhouette, lignes centrales des vaisseaux avec rayon (`VESSEL`/`P`), vues prédéfinies (`VIEW`) |
| `PHYSIO.CFG`  | Animation et physiologie : phases du cycle cardiaque, amplitude des battements, vitesses du sang, saturation en oxygène, profils de simulation (repos, effort, athlète, ...) |

Le programme cherche ces fichiers dans le répertoire courant, dans `SAMPLES\CS3DA`, puis à côté
de l'exécutable. Un modèle `.OBJ` simple (`v` / `f`) peut aussi être chargé avec `/MODEL` ou fusionné avec `/IMPORT`.

Usage : `CS3DA /?` pour la liste des options (`/VIEW`, `/MODEL`, `/SHOW`, `/HIDE`, `/CAMERA`, `/ZOOM`,
`/BACKGROUND`, `/HEART`, `/FLOW`, `/OXYGEN`, `/VESSELS`, `/PRESSURE`, `/SPEED`, `/PLAY`, `/PAUSE`,
`/STOP`, `/LOOP`, `/DURATION`, `/FPS`, `/IMPORT`, `/EXPORT`, `/FORMAT`, `/CONFIG`, `/PROFILE`, `/LOG`, `/QUIET`).

Dans l'application : F10 ou clic pour les menus, bouton gauche + glisser pour tourner, bouton droit +
glisser pour déplacer, clic sur un vaisseau pour le sélectionner, Espace pour lecture/pause, F1 pour la liste des raccourcis.
