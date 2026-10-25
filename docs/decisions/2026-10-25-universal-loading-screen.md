# Écran de chargement universel

## Décision

Le service autoloadé `SceneTransition` reste l'unique point d'entrée des changements de scènes. Il conserve les fondus existants et charge désormais les destinations avec `ResourceLoader.load_threaded_request()`.

Une scène `LoadingScreen` réutilisable est instanciée dans le même `CanvasLayer` que le fondu. Elle affiche une progression déterminée uniquement lorsque Godot fournit une valeur réelle. Sinon, la barre utilise son mode indéterminé natif.

Le démarrage natif utilise un Boot Splash PNG statique avec la même identité visuelle. Le démarrage Web utilise un Custom HTML Shell dérivé du shell Godot 4.7.1 et conserve les placeholders, le canvas, le contrôle de compatibilité, le service worker et `Engine.startGame()`.

## Raisons

- Centraliser évite de modifier les portails, les mini-jeux et leurs règles de progression.
- L'autoload survit au remplacement de la scène et peut continuer à animer l'interface pendant le chargement.
- Le chargement threadé évite de bloquer la boucle principale sur les scènes lourdes.
- Les chargements rapides ne reçoivent aucun délai artificiel.

## Erreurs

Si une ressource est invalide ou si son activation échoue, la scène courante reste en place. Le service affiche une erreur lisible, puis révèle de nouveau cette dernière scène valide. Il ne relance pas automatiquement le chargement.

## Limites

Le Boot Splash natif est statique : aucun script ne peut s'exécuter avant l'initialisation du moteur. L'animation commence avec le shell Web ou, sur PC, dès la première frame Godot.
