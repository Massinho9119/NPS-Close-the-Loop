## NUOVA QUERY PER TABELLA SURVEY WORDCLOUD

create or replace table `elc-cdpcrm-prj-prd.looker_crm_analytics.survey_wordcloud_translated_comments` AS

WITH original_comment AS ( --keep only comments (in original language) for banners that you do not want to translate
  SELECT
    a.survey_h_hid,
    a.invitation_date,
    b.banner banner,
    CONCAT(
      IFNULL(a.opt_ltr_followup_comment, ''),
      IFNULL(a.sun_ltr_followup_comment, ''),
      IFNULL(a.product_ltr_followup_comment, ''),
      IFNULL(a.verbatim, '')
    )  AS comment
  FROM 
    `elc-cdpcrm-prj-prd.vlt_mrt.survey_results` a
    inner join  `elc-cdpcrm-prj-prd.crm_analytics.dim_brand_nps` b on a.brand_id = b.brand_id
  WHERE
    b.banner not in ('Oliver Peoples'
        ,'Vogue'
        ,'Sunglass Hut'
        ,'Persol'
        ,'Solaris'
        ,'Oakley'
        ,'Ray-Ban'
        ,'Arnette'
        ,'VisionDirect')
        AND 
    CONCAT(
      IFNULL(a.opt_ltr_followup_comment, ''),
      IFNULL(a.sun_ltr_followup_comment, ''),
      IFNULL(a.product_ltr_followup_comment, ''),
      IFNULL(a.verbatim, '')
    ) != ''
),

translated_comment as ( --keep translated comments for banners that you want to translate
  select 
  survey_h_hid,
  invitation_date,
  brand as banner,
  translated_comment AS comment
  from `elc-cdpcrm-prj-prd.looker_crm_analytics.nps_gemini_comment_transl`
),

mydata as (select * from original_comment union all select * from translated_comment),

exploded_words AS (
  SELECT 
    survey_h_hid,
    invitation_date,
    banner,
    -- Remove unwanted symbols using REGEXP_REPLACE
    REGEXP_REPLACE(word, r'[,.:;!()]', '') AS word,
    LENGTH(REGEXP_REPLACE(word, r'[,.:;!()]', '')) AS word_length
  FROM (
    SELECT 
      survey_h_hid,
      invitation_date,
      banner,
      SPLIT(comment, ' ') AS words -- Split the comment into individual words
    FROM 
      mydata
  ), UNNEST(words) AS word -- Unnest the array of words into separate rows
  WHERE LENGTH(REGEXP_REPLACE(word, r'[,.:;!()]', '')) > 3 -- Filter words longer than 3 characters after removing symbols
)
SELECT 
  survey_h_hid,
  invitation_date,
  lower(word) as word,
  banner
FROM 
  exploded_words
WHERE 
  LOWER(word) NOT IN (
    'from', 'with', 'about', 'into', 'upon', 'after', 'under', 'before',  'when', 'very','they','this','there','would','your', "didn't",
    'between','will','which','were','that','them','what', 'through', 'verso', 'dentro', 'sopra', 'sotto', 'oltre', 
    'secondo', 'contro', 'attraverso', 'davanti', 'dietro', 'nella', 'sulla', 'della', 'because', 'have', 'been','even','then','avere','aveva','stati','alle','alla','stata','stato','state', 'avevo', 'sono', 'dove',
    
'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra', 'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'uno', 'una', 'e', 'o', 'ma', 'se', 'perché', 'anche', 'che', 'quindi', 'così', 'come', 'dopo', 'prima', 'mentre', 'ogni', 'tutti', 'tutte', 'lui', 'lei', 'noi', 'voi', 'loro', 'questo', 'quello', 'ci', 'ne', 'gli', 'lì', 'qua', 'là' ,

 'the', 'a', 'an', 'and', 'or', 'but', 'if', 'on', 'in', 'with', 'by', 'for', 'to', 'of', 'at', 'as', 'is', 'are', 'was', 'were', 'be', 'been', 'being', 'not', 'it', 'this', 'that', 'there', 'so', 'then', 'when', 'where', 'who', 'which', 'all', 'any', 'some', 'no', 'such', 'can', 'could', 'should', 'would', 'will', 'you', 'your', 'yours', 'he', 'she', 'we', 'they', 'them', 'these', 'those', 'here', 'about', 'how', 'my', 'his', 'her',

 'le', 'la', 'les', 'un', 'une', 'et', 'ou', 'mais', 'si', 'dans', 'sur', 'par', 'pour', 'avec', 'en', 'à', 'de', 'des', 'du', 'ce', 'cette', 'ces', 'il', 'elle', 'ils', 'elles', 'que', 'qui', 'quoi', 'donc', 'ainsi', 'comme', 'où', 'quand', 'alors', 'même', 'tout', 'tous', 'toutes', 'leur', 'leurs', 'cela', 'ici', 'là-bas', 'cela', 'celui', 'celle', 'ses', 'son', 'sa', 'mon', 'ma', 'mes',

'el', 'la', 'los', 'las', 'un', 'una', 'y', 'o', 'pero', 'si', 'en', 'con', 'de', 'por', 'para', 'a', 'que', 'quién', 'cual', 'como', 'donde', 'al', 'lo', 'le', 'es', 'fue', 'ha', 'del', 'este', 'ese', 'aquello', 'mi', 'mis', 'su', 'sus', 'ellos', 'ellas', 'nosotros', 'vosotros', 'alguno', 'ninguno', 'cualquiera', 'alguien', 'nadie', 'siempre', 'nunca', 'quizás', 'ahora', 'entonces', 'aquí', 'allí',

'der', 'die', 'das', 'ein', 'eine', 'und', 'oder', 'aber', 'wenn', 'auf', 'in', 'an', 'mit', 'zu', 'für', 'von', 'nach', 'bei', 'über', 'unter', 'als', 'ist', 'war', 'sind', 'nicht', 'dass', 'es', 'er', 'sie', 'wir', 'ihr', 'sie', 'man', 'dies', 'das', 'jenes', 'hier', 'dort', 'wo', 'wann', 'wie', 'wer', 'was', 'alle', 'jede', 'jemand', 'niemand', 'immer', 'nie', 'jetzt', 'schon', 'noch', 'dann', 'so',

 'o', 'a', 'os', 'as', 'um', 'uma', 'e', 'ou', 'mas', 'se', 'em', 'com', 'de', 'por', 'para', 'no', 'na', 'que', 'quem', 'qual', 'como', 'onde', 'ele', 'ela', 'eles', 'elas', 'foi', 'há', 'pelo', 'pela', 'sua', 'suas', 'meu', 'minha', 'nossos', 'nossas', 'vocês', 'deles', 'delas', 'isso', 'aquilo', 'aqui', 'lá', 'agora', 'então', 'todo', 'todos', 'tudo', 'algo', 'nada', 'sempre', 'nunca',


---

'col', 'coi', 'dagli', 'dalle', 'degli', 'delle', 'sotto', 'sopra', 'verso', 'contro', 'prima', 'tanto', 'tale', 'alcuno', 'alcuna', 'chi', 'ciò', 'ci', 'ne', 'niente', 'nulla', 'forse', 'poco', 'troppo', 'ancora', 'già', 'poi', 'sempre', 'mai', 'nessuno', 'certo', 'pure', 'mica', 'non',

'that', 'than', 'more', 'less', 'up', 'down', 'out', 'over', 'under', 'again', 'either', 'neither', 'both', 'because', 'before', 'after', 'few', 'many', 'much', 'quite', 'still', 'even', 'maybe', 'almost', 'just', 'already', 'yet', 'always', 'often', 'sometimes', 'never', 'everyone', 'everything', 'nothing',

 'pourtant', 'tandis', 'dès', 'depuis', 'autour', 'devant', 'derrière', 'entre', 'dessous', 'dessus', 'plutôt', 'peu', 'beaucoup', 'encore', 'déjà', 'jamais', 'toujours', 'souvent', 'parfois', 'aucun', 'aucune', 'quelqu’un', 'quelque', 'rien', 'tout', 'tous', 'très', 'quelques', 'chaque', 'ni', 'non',

'aunque', 'mientras', 'desde', 'hacia', 'sobre', 'debajo', 'delante', 'detrás', 'entre', 'alrededor', 'siempre', 'nunca', 'poco', 'mucho', 'tal', 'cual', 'algún', 'alguna', 'ningún', 'ninguna', 'algo', 'todo', 'todos', 'nadie', 'algunos', 'cualquier', 'cada', 'ninguno', 'jamás',

'bevor', 'nachdem', 'während', 'seit', 'weil', 'denn', 'obwohl', 'trotzdem', 'entweder', 'weder', 'noch', 'viel', 'wenig', 'manche', 'jeder', 'irgendwann', 'irgendwo', 'nirgendwo', 'überall', 'keiner', 'jemals', 'oft', 'selten', 'einige', 'niemand', 'immerhin', 'doch', 'jedoch', 'gerade',

 'enquanto', 'desde', 'até', 'sobre', 'sob', 'antes', 'depois', 'ainda', 'mesmo', 'nunca', 'sempre', 'pouco', 'muito', 'algum', 'alguma', 'nenhum', 'nenhuma', 'tanto', 'quanto', 'todo', 'toda', 'alguns', 'algumas', 'você', 'vos', 'aquele', 'aquela', 'deste', 'dessa', 'destes', 'disso',

"felt", "&", "glasses", "t", "very", "30", "up", "one", "ray", "ban", "stories", "customer", "out", "great", "1", "need", "really", "more", "back", "rayban", "doesn", "m", "short", "dont", "per", "second", "being", "2", "e", "wish", "back", "please", "view", "last", "poorreally", "s", "using", "dont", "don'tdi", "sucks", "don", "never", "even", "3", "10", "today", "didn", "make", "again", "told", "went", "know", "see", "still", "de", "didn't", "now", "que", "y", "la", "el", "los", "en", "por", "se", "mi", "con", "para", "o", "nao", "target", "optical", "lens", "crafters", "lenscrafters", "vision", "pearl", "vision", "ilori", "aspen", "gmo", "i", "the", "not", "one", "up", "i", "t", "go", "two", "came", "day", "another", "them.", "don't", "didnâ€™t", "don't", "no", "iâ€™ve", "over", "me", "me.", "take", "before", "after", "come", "same", "david", "clulow", "osi", "oakley", "sunglasshut", "rayban", "ray", "ban", "ray-ban", "opsm", "laubman&pank", "laubman", "pank", "native", "costa", "use", "times", "first", "going", "new", "picked", "-", "everything", "something", "nothing", "called", "way", "going", "took", "lady", "_", "feel", "made", "put", "bought", "glasses.com", "someone", "anyone", "i'm", "wasn't", "doesn't", "can't", "couldn't", "couldn't", "i", "i", "picked", "person", "use", "it.", "box", "want", "find", "different", "ask", "asked", "finally", "pearl", "pearlvision", "made", "arrived", "tried", "look", "wanted", "find", "itâ€™ts", "sent", "glasses.", "i'm", "it's", "sunglasses", "i've", "haven't", "it wasn't", "three", "extremely", "january", "thorough", "&", "hut", "muy", "sure", "much", "bot", "h", "glasses,", "sunglasses", "purchase", "purchased", "people", "job", "eye", "sunglass", "sun", "maui", "sunnies", "them!", "bit", "sunglasses.", "sunglasses!", "purchase.", "buy", "both", "n/a", "questions", "work", "years", "vision.", "pearle", "you.", "opsm.", "shopping", "you!", "getting", "frames", "frame", "highly", "absolutely", "pair", "everyone", "march", "na", "june", "july", "pairs", "readers.com", "i'm", "didn't", "choose", "having", "frames.", 
"readers", "like", "thank","readerscom", 
"lentilles", "lunettes", "j'ai",
"brille", "alles",
"atención", "lentes", "porque", "lentes", "hacer", "tienda", "pedido", "entrega", "cuando", "óculos", "loja", "entrega", "creo", "gafas",
"lenti", "negozio", "occhiali", "detto", "fatto",
"lenses", "contacts", "optometrist", "readers", "clearly", "said", "didn't", "left", "however", "eyebuydirect", "right", "haven't", "eyes", "foster", "grant", "glassescom", "only", "other", "lenstore", "native", "natives", "also", "without", "peoples", "oliver", "persol", "hanno", "hello", "solaris", "express", "wouldn't", "vogue",

"store", "said", "only", "help", "other", "also"
  );
