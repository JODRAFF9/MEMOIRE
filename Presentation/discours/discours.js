/* ============================================================
   Discours de soutenance, genere au format Word.
   Le texte suit l'ordre des diapositives de Presentation/main.tex.
   ============================================================ */
const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, AlignmentType,
  BorderStyle, PageNumber, Header, Footer, TabStopType, TabStopPosition,
} = require("docx");

const POLICE = "Times New Roman";

/* ── Repere de diapositive, en marge du discours ── */
const repere = (n, titre, duree) =>
  new Paragraph({
    spacing: { before: 320, after: 120 },
    border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: "1CABE2" } },
    children: [
      new TextRun({ text: `Diapositive ${n}`, bold: true, font: POLICE, size: 20, color: "0E6E96" }),
      new TextRun({ text: `  ·  ${titre}`, font: POLICE, size: 20, color: "6E747E" }),
      new TextRun({ text: `\t${duree}`, font: POLICE, size: 20, color: "6E747E" }),
    ],
    tabStops: [{ type: TabStopType.RIGHT, position: TabStopPosition.MAX }],
  });

/* ── Phrase d'attaque : ce par quoi on ouvre la diapositive ── */
const attaque = (texte) =>
  new Paragraph({
    spacing: { before: 60, after: 200 },
    children: [new TextRun({ text: texte, font: POLICE, size: 30, bold: true, color: "0E6E96" })],
  });

/* ── Paragraphe de discours ── */
const dire = (texte) =>
  new Paragraph({
    spacing: { after: 160, line: 360 },
    alignment: AlignmentType.JUSTIFIED,
    children: [new TextRun({ text: texte, font: POLICE, size: 24 })],
  });

/* ── Indication scenique ── */
const geste = (texte) =>
  new Paragraph({
    spacing: { after: 160 },
    indent: { left: 340 },
    children: [new TextRun({ text: texte, font: POLICE, size: 22, italics: true, color: "6E747E" })],
  });

const titre = (t) =>
  new Paragraph({
    heading: HeadingLevel.HEADING_1,
    spacing: { before: 400, after: 200 },
    children: [new TextRun({ text: t, bold: true, font: POLICE, size: 30, color: "0E6E96" })],
  });

const corps = [];

/* ============================================================
   Page de garde
   ============================================================ */
corps.push(
  new Paragraph({
    spacing: { before: 1200, after: 200 },
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "DISCOURS DE SOUTENANCE", bold: true, font: POLICE, size: 40, color: "0E6E96" })],
  }),
  new Paragraph({
    spacing: { after: 600 },
    alignment: AlignmentType.CENTER,
    children: [new TextRun({
      text: "Impact des transferts de migrants sur la pauvreté multidimensionnelle des enfants au Sénégal",
      font: POLICE, size: 28, italics: true,
    })],
  }),
  new Paragraph({
    spacing: { after: 120 },
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "Sié Rachid TRAORÉ", bold: true, font: POLICE, size: 26 })],
  }),
  new Paragraph({
    spacing: { after: 120 },
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "Sous la direction de Mamadou Abdoulaye DIALLO", font: POLICE, size: 24 })],
  }),
  new Paragraph({
    spacing: { after: 800 },
    alignment: AlignmentType.CENTER,
    children: [new TextRun({ text: "ENSAE Pierre Ndiaye  ·  Août 2026", font: POLICE, size: 24, color: "6E747E" })],
  }),
  new Paragraph({
    spacing: { after: 120 },
    alignment: AlignmentType.CENTER,
    children: [new TextRun({
      text: "Durée visée : 19 minutes  ·  31 diapositives",
      font: POLICE, size: 22, italics: true, color: "6E747E",
    })],
  }),
  new Paragraph({ children: [new TextRun({ text: "", break: 1 })], pageBreakBefore: true }),
);

/* ============================================================
   Ouverture
   ============================================================ */
corps.push(titre("Ouverture"));
corps.push(repere("de titre", "Page de garde", "30 s"));
corps.push(attaque("Très chers membres du jury, distingués membres de l'auditoire, je vous salue."));
corps.push(dire(
  "C'est un réel plaisir de vous présenter aujourd'hui les résultats de mon mémoire de fin d'études, " +
  "consacré à l'impact des transferts de migrants sur la pauvreté multidimensionnelle des enfants au Sénégal. " +
  "Ce travail a été mené sous la direction du Docteur Mamadou Abdoulaye Diallo, que je remercie pour son " +
  "accompagnement."
));
corps.push(dire(
  "Pour planter le décor : chaque année, plus de 1 200 milliards de francs CFA entrent au Sénégal " +
  "par les transferts des migrants, soit 12,1 % du produit intérieur brut : le quatrième récepteur " +
  "d'Afrique subsaharienne. Dans le même temps, un enfant sénégalais sur deux est privé " +
  "dans au moins quatre des sept domaines qui font son bien-être. Deux faits massifs, que rien " +
  "n'oblige à relier. C'est pourtant ce lien que mon travail met à l'épreuve."
));
corps.push(geste("Marquer un temps après « met à l'épreuve ». Passer à la diapositive du plan."));

corps.push(repere(1, "Plan de la présentation", "30 s"));
corps.push(attaque("Mon exposé suivra six temps."));
corps.push(dire(
  "Je poserai d'abord le contexte et la question de recherche. " +
  "Je situerai ensuite le travail dans la littérature. Je présenterai le cadre méthodologique, " +
  "c'est-à-dire les données, la mesure de la pauvreté et la stratégie d'identification. " +
  "Viendront alors les résultats, puis leur mise à l'épreuve et leur interprétation. " +
  "Je terminerai par la conclusion et les recommandations."
));

/* ============================================================
   1. Contexte et problématique
   ============================================================ */
corps.push(titre("Premier temps · Contexte et problématique"));

corps.push(repere(2, "Contexte général", "2 min"));
corps.push(attaque("Deux réalités coexistent au Sénégal."));
corps.push(dire(
  "La première est financière. Les transferts reçus de la diaspora sont passés de 233 millions de dollars " +
  "en 2000 à 2 220 millions en 2017, soit de 166 à 1 242 milliards de francs CFA. Ils représentent " +
  "12,1 pour cent du produit intérieur brut, ce qui place le Sénégal au quatrième rang des récepteurs " +
  "d'Afrique subsaharienne. Rapportés au ménage, les montants reçus avoisinent le seuil de pauvreté " +
  "monétaire annuel par tête : il ne s'agit donc pas d'un appoint marginal, mais d'une ressource qui " +
  "peut, en théorie, changer les conditions de vie."
));
corps.push(dire(
  "La seconde réalité est celle des enfants. En 2018, 50,7 pour cent des enfants de 0 à 17 ans étaient " +
  "privés dans au moins quatre des sept domaines de leur bien-être : l'éducation, la santé, la nutrition, " +
  "l'eau, l'assainissement, le logement et la protection. Ces manques échappent largement aux mesures " +
  "fondées sur le seul revenu du ménage. Un enfant peut vivre dans un ménage situé au-dessus du seuil " +
  "monétaire et rester déscolarisé, ou boire une eau non potable."
));
corps.push(geste("Insister sur le contraste entre les deux blocs avant d'enchaîner."));

corps.push(repere(3, "Problématique", "1 min"));
corps.push(attaque("D'où la question qui structure ce mémoire."));
corps.push(dire(
  "Dans quelle mesure les transferts de migrants réduisent-ils " +
  "la pauvreté multidimensionnelle des enfants au Sénégal ?"
));
corps.push(dire(
  "La réponse n'a rien d'évident. Les transferts desserrent la contrainte budgétaire du ménage, mais " +
  "un supplément de ressources ne se traduit pas mécaniquement par un recul des privations. Et surtout, " +
  "recevoir des transferts suppose un réseau migratoire : les ménages bénéficiaires diffèrent des autres " +
  "avant même le premier franc reçu. Toute comparaison directe attribuerait aux transferts des écarts " +
  "qui leur préexistent."
));

corps.push(repere(4, "Objectifs et hypothèses", "1 min"));
corps.push(attaque("Cette question se décline en deux objectifs et deux hypothèses."));
corps.push(dire(
  "L'objectif général est d'évaluer cet impact. Il se décline en deux objectifs spécifiques : " +
  "construire un indice de pauvreté multidimensionnelle adapté aux enfants sénégalais, puis estimer " +
  "l'effet des transferts sur cet indice et en analyser l'hétérogénéité."
));
corps.push(dire(
  "Deux hypothèses sont testées. La première, que les transferts réduisent significativement cette pauvreté. " +
  "La seconde, que leur effet est hétérogène selon les dimensions du bien-être, le milieu de résidence, " +
  "le genre du chef de ménage, l'âge de l'enfant et le montant reçu."
));

/* ============================================================
   2. Revue de la littérature
   ============================================================ */
corps.push(titre("Deuxième temps · Revue de la littérature"));

corps.push(repere(5, "Théories de la migration", "1 min 15"));
corps.push(attaque("Un mot d'abord sur la migration elle-même."));
corps.push(dire(
  "La décision de migrer et celle d'envoyer des fonds " +
  "sont indissociables. La théorie néoclassique explique la migration par un calcul d'investissement : " +
  "l'individu migre si la valeur actualisée des gains attendus à destination, nette des coûts du " +
  "déplacement, excède ses gains d'origine, la décision se fondant sur le revenu espéré plutôt " +
  "qu'effectif. Les envois de fonds sont alors le rendement de cet investissement migratoire."
));
corps.push(dire(
  "La théorie des réseaux complète cette approche. Les liens de parenté, d'amitié ou de communauté " +
  "d'origine forment un capital social qui abaisse les coûts et les risques du départ : le migrant " +
  "installé héberge le nouvel arrivant, l'informe et lui trouve un emploi. Chaque migration facilite " +
  "ainsi les suivantes."
));
corps.push(dire(
  "J'insiste sur ce point, car il commande toute la suite du travail. Un ménage ne reçoit des transferts " +
  "que si l'un des siens a pu émigrer, et il ne le peut que s'il dispose d'un réseau. Or l'accès au réseau " +
  "dépend de l'histoire migratoire de la famille et du village, de la richesse initiale et des relations " +
  "sociales du ménage. Les bénéficiaires diffèrent donc des autres avant même le premier franc reçu, " +
  "et sur des caractéristiques dont certaines sont inobservables. C'est précisément ce que la stratégie " +
  "d'identification devra traiter."
));
corps.push(geste("C'est le point charnière de l'exposé : le dire lentement."));

corps.push(repere(6, "Canaux de transmission", "1 min 30"));
corps.push(attaque("Pourquoi les migrants transfèrent-ils, et avec quels effets ?"));
corps.push(dire(
  "La littérature apporte trois enseignements."
));
corps.push(dire(
  "Le premier concerne les motivations. Trois familles se dégagent : l'altruisme, où les transferts " +
  "décroissent avec le revenu du receveur ; l'intérêt personnel et l'échange, où il s'agit de préserver " +
  "un héritage ou de rembourser la dette du départ ; et la diversification du risque, où les transferts " +
  "assurent le ménage contre les chocs. Ces motivations importent, parce qu'elles déterminent qui reçoit, " +
  "combien, et pour quoi."
));
corps.push(dire(
  "Le deuxième porte sur les effets établis. Sur la pauvreté monétaire, le recul est modeste et atténué " +
  "par les coûts de transaction. Sur l'éducation, la scolarisation progresse. Sur la nutrition, les effets " +
  "ne se confirment pas d'une étude à l'autre et dépendent du maintien du lien avec le migrant."
));

corps.push(repere(7, "Mesure multidimensionnelle", "1 min"));
corps.push(attaque("Mesurer la pauvreté d'un enfant par le seul revenu ne suffit pas."));
corps.push(dire(
  "Le troisième enseignement est une lacune. Les travaux existants raisonnent le plus souvent au niveau " +
  "du ménage et sur des indicateurs monétaires. Aucune étude recensée ne combine, en Afrique de l'Ouest, " +
  "une mesure multidimensionnelle de la pauvreté infantile et une identification sur données de suivi. " +
  "C'est précisément l'espace que ce mémoire occupe."
));

/* ============================================================
   3. Cadre méthodologique
   ============================================================ */
corps.push(titre("Troisième temps · Cadre méthodologique"));

corps.push(repere(8, "Données EHCVM I et II", "1 min 30"));
corps.push(attaque("J'en viens aux données."));
corps.push(dire(
  "Le travail repose sur les deux vagues de l'Enquête harmonisée sur les conditions de vie des ménages : " +
  "la première de 2018-2019, la seconde de 2021-2022. Leur appariement permet de suivre 6 127 ménages " +
  "d'une vague à l'autre."
));
corps.push(dire(
  "L'unité d'analyse n'est pas le ménage mais l'enfant. Grâce à l'identifiant préchargé du questionnaire " +
  "de 2021, 17 786 enfants de 0 à 17 ans sont suivis individuellement : 2 638 vivaient en 2018 dans un " +
  "ménage bénéficiaire, 15 148 dans un ménage non bénéficiaire. Le score de propension et l'appariement " +
  "sont estimés à ce niveau."
));

corps.push(repere(9, "MODA en 7 dimensions", "1 min 30"));
corps.push(attaque("Comment mesure-t-on cette pauvreté ?"));
corps.push(dire(
  "La pauvreté est mesurée par l'approche MODA, développée par l'UNICEF et reprise par l'ANSD. " +
  "Sept dimensions du bien-être de l'enfant sont retenues : l'assainissement, l'eau, le logement, " +
  "la nutrition, la santé, la protection et l'éducation. Elles se déclinent en quatorze indicateurs, " +
  "appliqués selon trois groupes d'âge : les 0 à 4 ans, les 5 à 14 ans et les 15 à 17 ans."
));
corps.push(dire(
  "Deux seuils interviennent. À l'intérieur d'une dimension, l'enfant est considéré comme privé dès qu'il " +
  "l'est dans au moins un indicateur. Entre dimensions, il est déclaré pauvre dès qu'il cumule au moins " +
  "quatre privations sur sept. La matrice complète des indicateurs et de leurs seuils figure en annexe, " +
  "et je peux y revenir si vous le souhaitez."
));
corps.push(geste("Signaler du geste le bouton de renvoi vers l'annexe."));

corps.push(repere(10, "Le problème d'identification", "1 min 30"));
corps.push(attaque("J'en viens au cœur méthodologique du travail."));
corps.push(dire(
  "J'en viens à la stratégie d'identification, qui est le cœur méthodologique du travail."
));
corps.push(dire(
  "Le traitement est défini au niveau du ménage : sont traités les ménages qui reçoivent, en 2018, " +
  "un transfert d'un expéditeur vivant hors du Sénégal et ayant déjà vécu dans le ménage. Ce statut est " +
  "figé à la période de base, ce qui garantit qu'il ne dépend pas de l'évolution ultérieure des privations."
));
corps.push(dire(
  "Le paramètre visé est l'effet moyen du traitement sur les traités. Sa difficulté est connue : " +
  "le contrefactuel, c'est-à-dire ce qu'auraient vécu les enfants bénéficiaires en l'absence de transfert, " +
  "n'est pas observable. Il faut donc le reconstruire."
));

corps.push(repere(11, "Le score de propension", "1 min"));
corps.push(attaque("Première brique, l'appariement."));
corps.push(dire(
  "Un modèle logit estime, pour chaque enfant, " +
  "la probabilité de vivre dans un ménage bénéficiaire, à partir des caractéristiques du chef de ménage, " +
  "de la taille du ménage, de la dépense par tête, du milieu et de la région, ainsi que du genre et de " +
  "l'âge de l'enfant. Chaque enfant traité est ensuite apparié à ses quatre plus proches voisins, sur le " +
  "support commun. Cette étape corrige la sélection sur les caractéristiques observables, mais elle laisse " +
  "subsister tout ce qui ne s'observe pas."
));

corps.push(repere(12, "La double différence", "1 min"));
corps.push(attaque("Seconde brique, la double différence."));
corps.push(dire(
  "Elle compare l'évolution des bénéficiaires entre 2018 et 2021 " +
  "à celle des témoins sur la même période. Ce faisant, elle élimine tous les déterminants inobservés qui " +
  "restent stables dans le temps, par exemple les aptitudes du ménage ou son rapport à la scolarisation. " +
  "Mais prise seule, elle suppose des groupes comparables au départ, ce qui n'est pas le cas ici."
));

corps.push(repere(13, "L'estimateur retenu", "1 min"));
corps.push(attaque("L'estimateur retenu combine les deux."));
corps.push(dire(
  "Il suit Heckman et ses coauteurs : la double différence est " +
  "calculée sur les seuls enfants appariés, chaque témoin entrant avec le poids que lui donne l'appariement. " +
  "Les deux limites se compensent alors : l'appariement rend les groupes comparables sur l'observable, " +
  "la double différence neutralise l'inobservable stable."
));

/* ============================================================
   4. Résultats
   ============================================================ */
corps.push(titre("Quatrième temps · Résultats empiriques"));

corps.push(repere(14, "État des lieux", "1 min"));
corps.push(attaque("Avant l'effet des transferts, un état des lieux."));
corps.push(dire(
  "L'incidence de la pauvreté multidimensionnelle recule " +
  "de 63,5 pour cent en 2018 à 57,8 pour cent en 2021. Mais l'intensité, c'est-à-dire le nombre moyen de " +
  "privations parmi les enfants pauvres, reste quasi stable, à un peu plus de 70 pour cent. " +
  "Autrement dit, il y a moins d'enfants pauvres, mais ceux qui le restent cumulent toujours près de " +
  "cinq privations sur sept. La distribution, à droite, montre que le seuil de quatre dimensions se situe " +
  "au voisinage du mode."
));

corps.push(repere(15, "Ventilation par sous-groupe", "45 s"));
corps.push(attaque("Un fait ressort de la ventilation par sous-groupe."));
corps.push(dire(
  "Par groupe d'âge et par genre du chef de ménage, un fait ressort : les enfants des ménages bénéficiaires " +
  "partent d'un niveau nettement plus favorable. Chez les 0 à 4 ans, leur avantage passe de 23,7 à " +
  "16,9 points entre les deux vagues, tiré par la nutrition. Cet avantage précède le traitement, " +
  "et c'est exactement ce que l'appariement doit corriger."
));

corps.push(repere(16, "Incidence selon le statut", "30 s"));
corps.push(attaque("Voici la même incidence, décomposée par statut."));
corps.push(dire(
  "La courbe décompose l'incidence d'ensemble selon le statut du ménage. Les deux groupes reculent, " +
  "mais l'écart de départ est manifeste et il ne se referme pas."
));

corps.push(repere(17, "Qualité de l'appariement", "1 min"));
corps.push(attaque("Un mot sur la qualité de l'appariement, dont tout dépend."));
corps.push(dire(
  "Avant de commenter l'effet, un mot sur la qualité de l'appariement, dont dépend la crédibilité de tout " +
  "ce qui suit. Le logit est estimé sur 17 735 enfants. La différence standardisée moyenne entre traités " +
  "et témoins passe de 11,4 pour cent avant appariement à 2,4 pour cent après, très en deçà du seuil " +
  "usuel de 10 pour cent, et le test joint de nullité des covariables n'est plus rejeté. " +
  "L'échantillon apparié compte 16 210 observations-enfants sur le support commun."
));
corps.push(geste("Ne pas s'attarder : le jury retient surtout que l'équilibre est atteint."));

corps.push(repere(18, "Le résultat central", "2 min"));
corps.push(attaque("J'en viens au résultat central, et je vais l'énoncer sans détour."));
corps.push(dire(
  "Sur la période 2018-2021, la pauvreté multidimensionnelle des enfants des ménages bénéficiaires recule " +
  "plus lentement que celle des témoins appariés. L'écart est de 6,4 points de pourcentage, significatif " +
  "au seuil de 5 pour cent. Le résultat ne tient pas au choix de l'algorithme : les trois appariements " +
  "concordent, de 0,050 à 0,064. La double différence sans appariement, qui ne corrige pas l'avantage " +
  "initial, donne le même signe atténué, à 0,035."
));
corps.push(dire(
  "La première hypothèse n'est donc pas validée. Je précise immédiatement le sens de ce résultat, " +
  "car il se prête à un contresens : il ne dit pas que les transferts appauvrissent les enfants. " +
  "Il dit que, sur cet horizon de trois ans, les conditions de vie des enfants bénéficiaires se sont " +
  "améliorées plus lentement que celles de leurs témoins."
));

corps.push(repere(19, "Effets par dimension", "1 min"));
corps.push(attaque("Cet effet n'est pas diffus : il se localise."));
corps.push(dire(
  "L'effet n'est pas diffus, il se localise. Sur les sept dimensions, une seule ressort : la nutrition, " +
  "avec 6,8 points, significative à 10 pour cent, et c'est précisément la dimension qui dépend le plus " +
  "directement du budget courant du ménage. L'assainissement va dans le même sens, à 4,6 points, sans " +
  "atteindre la significativité. Les cinq autres dimensions restent comprises entre 0,5 et 2,4 points, " +
  "toutes non significatives."
));
corps.push(dire(
  "Par groupe d'âge, l'effet n'est établi que chez les 0 à 4 ans, à 9,1 points, significatif à " +
  "5 pour cent. Effet par âge et effet par dimension se répondent : les besoins des plus jeunes passent " +
  "d'abord par l'alimentation. En revanche, aucun test d'égalité ne conclut, ni entre milieux, " +
  "ni selon le genre du chef, ni entre tranches d'âge : les sous-groupes se distinguent par la " +
  "significativité de leur effet, non par une ampleur supérieure."
));

corps.push(repere(20, "Effet selon le montant", "1 min"));
corps.push(attaque("Dernier volet, l'intensité du traitement."));
corps.push(dire(
  "L'écart défavorable se concentre sur les plus faibles " +
  "montants : seuls les deux premiers quintiles sont significatifs, à 12,9 et 9,9 points. Il ne se " +
  "retrouve pas pour les transferts les plus élevés, le dernier quintile étant même très légèrement " +
  "négatif. La pente dose-réponse, estimée sur le logarithme du montant, vaut moins 0,025 et est " +
  "significative à 10 pour cent : plus le montant reçu est élevé, plus l'écart tend à se réduire."
));
corps.push(dire(
  "Je dois toutefois nuancer : le profil n'est pas strictement monotone, le quatrième quintile remontant " +
  "sans être significatif. Et le montant relevant du choix du migrant, ce gradient se lit comme une " +
  "association conditionnelle, non comme un effet causal du montant."
));

/* ============================================================
   5. Robustesse et discussion
   ============================================================ */
corps.push(titre("Cinquième temps · Robustesse et discussion"));

corps.push(repere(21, "Tests de robustesse", "1 min"));
corps.push(attaque("Ce résultat a été mis à l'épreuve de trois façons."));
corps.push(dire(
  "Le résultat a été mis à l'épreuve de trois façons. Le choix de la méthode d'appariement, d'abord : " +
  "les trois algorithmes donnent un effet de 0,050 à 0,064, tous significatifs au moins à 10 pour cent. " +
  "Le seuil de privation ensuite : testé de une à sept dimensions, l'ampleur suit une courbe en cloche, " +
  "maximale au seuil retenu et significative seulement pour deux, trois et quatre dimensions. " +
  "Cela nous apprend quelque chose : l'effet se joue au milieu de la distribution des privations, " +
  "pas dans son noyau. Enfin, une implémentation indépendante du même estimateur retrouve le résultat."
));

corps.push(repere(22, "Sensibilité à la définition du traitement", "45 s"));
corps.push(attaque("Un test mérite d'être signalé, car il nuance la portée du résultat."));
corps.push(dire(
  "Si l'on restreint les traités aux " +
  "bénéficiaires des deux vagues, l'effet tombe à 0,022 en double différence et à moins 0,008 avec " +
  "appariement, tous deux non significatifs. L'exposition de ces ménages, déjà en cours en 2018, relève " +
  "d'une autre question que celle du design principal. Autrement dit : le signe et l'ordre de grandeur " +
  "résistent à l'algorithme comme au seuil, mais la définition du traitement les fait disparaître."
));

corps.push(repere(23, "Mécanismes d'interprétation", "1 min 30"));
corps.push(attaque("Comment expliquer qu'une ressource de cette ampleur ne réduise pas les privations ?"));
corps.push(dire(
  "Trois mécanismes me paraissent devoir être avancés."
));
corps.push(dire(
  "L'usage des fonds, d'abord. 68,5 pour cent des transferts relèvent du soutien courant et moins d'un " +
  "dixième va explicitement à la santé ou à la scolarité. Un flux qui finance l'ordinaire du ménage a peu " +
  "de raisons de déplacer les seuils de privation retenus par l'indice."
));
corps.push(dire(
  "La contrainte d'offre, ensuite. L'eau, l'assainissement et l'accès aux soins supposent des " +
  "investissements collectifs que le pouvoir d'achat privé ne remplace pas. Le fait que la privation " +
  "en santé touche 97 pour cent des enfants aux deux vagues, quasiment sans écart entre bénéficiaires et " +
  "témoins en 2021, en est l'illustration la plus nette."
));
corps.push(dire(
  "La marge sur laquelle l'effet opère, enfin. La sensibilité au seuil montre que l'écart se joue chez les " +
  "enfants situés au milieu de la distribution. Le noyau des enfants cumulant six ou sept privations relève " +
  "de déficits structurels qu'aucun flux monétaire privé ne déplace en trois ans."
));

corps.push(repere(24, "Validation des hypothèses", "30 s"));
corps.push(attaque("Que deviennent alors mes deux hypothèses ?"));
corps.push(dire(
  "Au terme de ce parcours, la première hypothèse n'est pas validée : l'effet est de signe défavorable et " +
  "aucune réduction n'est observée sur l'horizon. La seconde est partiellement validée : l'effet est bien " +
  "hétérogène selon les dimensions et selon le montant, mais aucun test d'égalité ne conclut par milieu, " +
  "genre du chef ou tranche d'âge."
));

/* ============================================================
   6. Conclusion
   ============================================================ */
corps.push(titre("Sixième temps · Conclusion et recommandations"));

corps.push(repere(25, "Conclusion générale", "1 min"));
corps.push(attaque("Quatre apports se dégagent de ce travail."));
corps.push(dire(
  "Une mesure de la pauvreté multidimensionnelle des enfants sur deux vagues " +
  "de l'EHCVM, selon l'approche MODA. Le constat d'un recul réel de l'incidence, de 63,5 à 57,8 pour cent, " +
  "sur fond d'une pauvreté qui reste massive. Le résultat central, à savoir que les transferts ne réduisent " +
  "pas, à trois ans, la pauvreté multidimensionnelle des enfants. Et sa localisation précise : " +
  "la nutrition, les 0 à 4 ans et les plus faibles montants reçus."
));

corps.push(repere(26, "Recommandations", "1 min 30"));
corps.push(attaque("Les recommandations suivent l'ordre de ces faits."));
corps.push(dire(
  "Là où l'écart se concentre, d'abord : donner la priorité à la sécurité alimentaire des enfants dans " +
  "les zones d'émigration, cibler les enfants de 0 à 4 ans des ménages bénéficiaires, et accompagner en " +
  "priorité les ménages qui reçoivent les plus faibles montants. J'insiste sur un point : recevoir des " +
  "transferts ne doit pas valoir exclusion des filets sociaux, puisque c'est précisément chez ces " +
  "ménages que la trajectoire est la moins favorable."
));
corps.push(dire(
  "Sur les conditions de conversion des transferts, ensuite : réduire les coûts de transaction des envois " +
  "formels, compléter les transferts par l'offre publique de services de base, et renforcer le suivi " +
  "statistique des transferts. Le message est simple : le transfert privé ne remplace pas l'investissement " +
  "collectif, il le suppose."
));

corps.push(repere(27, "Limites de l'étude", "1 min"));
corps.push(attaque("Ce travail a ses limites, et je préfère les énoncer moi-même."));
corps.push(dire(
  "L'hypothèse de tendances parallèles " +
  "n'est pas testable directement, deux vagues seulement étant disponibles ; l'appariement sur les niveaux " +
  "initiaux la rend plus crédible sans la démontrer. Les enfants vieillissent entre les deux enquêtes et " +
  "sont évalués sur la grille de leur âge courant ; le fait de figer les groupes d'âge à la période de base " +
  "neutralise l'essentiel de cet effet. Enfin, la nutrition et la santé reposent sur les seuls indicateurs " +
  "strictement comparables entre les deux vagues, car un indicateur redéfini entre 2018 et 2021 produirait " +
  "un effet mesuré sans contenu causal."
));

corps.push(repere(28, "Perspectives", "30 s"));
corps.push(attaque("Trois prolongements me semblent utiles."));
corps.push(dire(
  "Analyser les mécanismes de transmission à travers les dépenses " +
  "d'éducation, de santé et de logement ; intégrer la durée d'exposition aux transferts et leurs usages " +
  "effectifs, que le statut binaire ne capte pas ; et étendre l'analyse aux autres pays de l'UEMOA couverts " +
  "par l'EHCVM, dont le questionnaire est harmonisé."
));

/* ============================================================
   Clôture
   ============================================================ */
corps.push(titre("Clôture"));
corps.push(repere("finale", "Merci de votre attention", "20 s"));
corps.push(attaque("Je vous remercie de votre attention."));
corps.push(dire(
  "Je me tiens à votre disposition pour vos questions."
));
corps.push(geste(
  "Rester debout, face au jury, sans se rasseoir immédiatement. Deux annexes sont accessibles par " +
  "bouton : la matrice MODA complète, et les motifs et montants des transferts."
));

/* ============================================================
   Réponses préparées
   ============================================================ */
corps.push(new Paragraph({ children: [new TextRun("")], pageBreakBefore: true }));
corps.push(titre("Réponses préparées aux questions attendues"));

const qr = [
  ["Pourquoi un effet de signe défavorable ?",
   "Parce que les bénéficiaires partaient d'un niveau plus favorable et que leur avantage s'érode : " +
   "l'incidence recule chez tous, mais moins vite chez eux. Les trois mécanismes que j'ai exposés, " +
   "l'usage des fonds, la contrainte d'offre et la marge sur laquelle l'effet opère, expliquent " +
   "pourquoi l'apport monétaire ne suffit pas à maintenir cet avantage."],
  ["Votre écart de 63,5 pour cent avec les 50,7 pour cent de l'ANSD et de l'UNICEF ?",
   "Les deux chiffres ne portent pas sur le même échantillon. Le mien est restreint aux enfants suivis " +
   "aux deux vagues, ce qui exclut notamment les naissances postérieures à 2018 et les enfants des " +
   "ménages perdus de vue. La construction des indicateurs, contrainte par la comparabilité entre " +
   "vagues, joue également."],
  ["Comment justifiez-vous l'hypothèse de tendances parallèles ?",
   "Je ne peux pas la tester directement avec deux vagues, et je l'assume. L'appariement sur les " +
   "caractéristiques observables à la période de base la rend plus crédible, puisque les groupes " +
   "comparés partent de niveaux et de profils voisins. C'est une limite du dispositif, pas un oubli."],
  ["Pourquoi le seuil de quatre dimensions ?",
   "C'est le seuil retenu par l'ANSD et l'UNICEF, ce qui assure la comparabilité avec les travaux " +
   "existants. Je l'ai en outre fait varier de une à sept dimensions : l'ampleur suit une courbe en " +
   "cloche, maximale à quatre, ce qui montre que le résultat ne dépend pas d'un choix arbitraire."],
  ["Pourquoi l'enfant plutôt que le ménage comme unité d'analyse ?",
   "Parce que les privations qui nous intéressent sont individuelles : la scolarisation, l'acte de " +
   "naissance, l'illettrisme ne se mesurent pas au niveau du ménage. Deux enfants d'un même ménage " +
   "peuvent connaître des situations différentes selon leur âge."],
  ["Le résultat contredit-il la littérature ?",
   "Il la nuance plutôt qu'il ne la contredit. La littérature établit des effets sur la pauvreté " +
   "monétaire et sur la scolarisation, mesurés au niveau du ménage. Je mesure autre chose, une pauvreté " +
   "multidimensionnelle de l'enfant, sur un horizon de trois ans, et je corrige une sélection que " +
   "beaucoup de travaux transversaux ne corrigent pas."],
];
qr.forEach(([q, r]) => {
  corps.push(new Paragraph({
    spacing: { before: 280, after: 100 },
    children: [new TextRun({ text: q, bold: true, font: POLICE, size: 24, color: "0E6E96" })],
  }));
  corps.push(dire(r));
});

/* ============================================================
   Assemblage
   ============================================================ */
const doc = new Document({
  creator: "Sié Rachid TRAORÉ",
  title: "Discours de soutenance",
  sections: [{
    properties: { page: { margin: { top: 1134, right: 1134, bottom: 1134, left: 1134 } } },
    headers: {
      default: new Header({
        children: [new Paragraph({
          alignment: AlignmentType.RIGHT,
          children: [new TextRun({
            text: "Discours de soutenance  ·  Sié Rachid TRAORÉ",
            font: POLICE, size: 18, color: "6E747E",
          })],
        })],
      }),
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [new TextRun({ children: [PageNumber.CURRENT], font: POLICE, size: 18, color: "6E747E" })],
        })],
      }),
    },
    children: corps,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("discours_soutenance.docx", buf);
  console.log(">>> discours_soutenance.docx genere");
});
