# Modèles de document 

Les modèles de document contiennent la définition de vos documents et servent à les imprimer (devis, factures, fiche client...). Il est possible d'archiver les impressions.

{:.alert .alert-success}
Il existe des **modèles de document par défaut** comme la facture de vente ou le devis/commande, lesquels peuvent être (re)chargés à tout moment en utilisant le bouton <i />{:.icon .icon-refresh}.

## Gestion des modèles 

**Type** :
Le type de document définit ce que le modèle est sensé produire.
Pour plus d'informations sur cette notion, il vous faut vous rendre dans l'[espace GED](backend/documents).

**Méthode d'archivage** (vers la GED) :
La méthode d'archivage permet de piloter le comportement du logiciel vis à vis de l'archivage.

* **Aucun du type** : Aucun document du type n'est archivé (tous modèles confondus)
* **Premier du type** : Seul le premier document du type est archivé (tous modèles confondus)
* **Dernier du type** : Seul le dernier document du type est archivé (tous modèles confondus)
* **Tous du type** : L'ensemble des documents du type est archivé (tous modèles confondus)
* **Aucun du modèle** : Aucun document du modèle n'est archivé
* **Premier du modèle** : Seul le premier document du modèle est archivé
* **Dernier du modèle** : Seul le dernier document du modèle est archivé
* **Tous du modèle** : L'ensemble des documents du modèle est archivé

{:.alert .alert-warning}
En sélectionnant une des 4 premières méthodes d'archivage pour un modèle donné, vous mettrez à jour automatiquement les autres modèles du même type.

Les archives déjà enregistrées sont conservées si vous choisissez de ne plus archiver les documents d'un modèle ou d'un type donné.

{:.alert .alert-success}
Tous les documents **téléversés** sont conservés indépendamment de la méthode d'archivage sélectionnée.

## Personnalisation des modèles 

Il est possible de créer/modifier des modèles via le logiciel libre _Jasper iReport_.
