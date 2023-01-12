--
-- PostgreSQL database dump
--

-- Dumped from database version 11.18 (Debian 11.18-1.pgdg100+1)
-- Dumped by pg_dump version 14.6 (Ubuntu 14.6-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

CREATE SCHEMA observations;

--
-- Name: espece; Type: TABLE; Schema: observations; Owner: -
--

CREATE TABLE observations.espece (
    es_id integer NOT NULL,
    es_nom_commun text NOT NULL,
    es_nom_valide text,
    es_nom_public text
);


--
-- Name: TABLE espece; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON TABLE observations.espece IS 'Liste des espèces';


--
-- Name: COLUMN espece.es_id; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.espece.es_id IS 'Identifiant de l''espèce';


--
-- Name: COLUMN espece.es_nom_commun; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.espece.es_nom_commun IS 'Nom commun';


--
-- Name: COLUMN espece.es_nom_valide; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.espece.es_nom_valide IS 'Nom scientifique valide';


--
-- Name: COLUMN espece.es_nom_public; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.espece.es_nom_public IS 'Nom public';


--
-- Name: espece_es_id_seq; Type: SEQUENCE; Schema: observations; Owner: -
--

CREATE SEQUENCE observations.espece_es_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: espece_es_id_seq; Type: SEQUENCE OWNED BY; Schema: observations; Owner: -
--

ALTER SEQUENCE observations.espece_es_id_seq OWNED BY observations.espece.es_id;


--
-- Name: nombres; Type: TABLE; Schema: observations; Owner: -
--

CREATE TABLE observations.nombres (
    code integer NOT NULL
);


--
-- Name: TABLE nombres; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON TABLE observations.nombres IS 'Liste de nombres. Utilisé comme source de valeurs pour les champs qui contiennent des nombres';


--
-- Name: COLUMN nombres.code; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.nombres.code IS 'Nombre';


--
-- Name: nomenclature; Type: TABLE; Schema: observations; Owner: -
--

CREATE TABLE observations.nomenclature (
    champ text NOT NULL,
    code text NOT NULL,
    valeur text,
    description text
);


--
-- Name: TABLE nomenclature; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON TABLE observations.nomenclature IS 'Table de nomenclature : contient l''ensemble des items des listes de valeur';


--
-- Name: COLUMN nomenclature.champ; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.nomenclature.champ IS 'Champ';


--
-- Name: COLUMN nomenclature.code; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.nomenclature.code IS 'Code';


--
-- Name: COLUMN nomenclature.valeur; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.nomenclature.valeur IS 'Valeur ( libellé )';


--
-- Name: COLUMN nomenclature.description; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.nomenclature.description IS 'Description';


--
-- Name: observation; Type: TABLE; Schema: observations; Owner: -
--

CREATE TABLE observations.observation (
    id_obs integer NOT NULL,
    prenom text,
    nom text,
    date_obs timestamp without time zone NOT NULL,
    type_obs text NOT NULL,
    espece integer NOT NULL,
    individu_isole boolean,
    distance_observation text,
    mode_observation text,
    etat_mer text,
    mm_charger_photo text,
    geom public.geometry(Point,4326) NOT NULL
);


--
-- Name: TABLE observation; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON TABLE observations.observation IS 'Observations faunistiques';


--
-- Name: COLUMN observation.id_obs; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.id_obs IS 'Identifiant';


--
-- Name: COLUMN observation.prenom; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.prenom IS 'Prénom';


--
-- Name: COLUMN observation.nom; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.nom IS 'Nom';


--
-- Name: COLUMN observation.date_obs; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.date_obs IS 'Date de l''observation';


--
-- Name: COLUMN observation.type_obs; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.type_obs IS 'Type';


--
-- Name: COLUMN observation.espece; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.espece IS 'Espèce';


--
-- Name: COLUMN observation.individu_isole; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.individu_isole IS 'Individu isolé ?';


--
-- Name: COLUMN observation.distance_observation; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.distance_observation IS 'Distance d''observation';


--
-- Name: COLUMN observation.mode_observation; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.mode_observation IS 'Mode d''observation';


--
-- Name: COLUMN observation.etat_mer; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.etat_mer IS 'Etat de la mer';


--
-- Name: COLUMN observation.mm_charger_photo; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.mm_charger_photo IS 'Photographie';


--
-- Name: COLUMN observation.geom; Type: COMMENT; Schema: observations; Owner: -
--

COMMENT ON COLUMN observations.observation.geom IS 'Géométrie de l''observation (point)';


--
-- Name: observation_id_obs_seq; Type: SEQUENCE; Schema: observations; Owner: -
--

CREATE SEQUENCE observations.observation_id_obs_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: observation_id_obs_seq; Type: SEQUENCE OWNED BY; Schema: observations; Owner: -
--

ALTER SEQUENCE observations.observation_id_obs_seq OWNED BY observations.observation.id_obs;


--
-- Name: espece es_id; Type: DEFAULT; Schema: observations; Owner: -
--

ALTER TABLE ONLY observations.espece ALTER COLUMN es_id SET DEFAULT nextval('observations.espece_es_id_seq'::regclass);


--
-- Name: observation id_obs; Type: DEFAULT; Schema: observations; Owner: -
--

ALTER TABLE ONLY observations.observation ALTER COLUMN id_obs SET DEFAULT nextval('observations.observation_id_obs_seq'::regclass);


--
-- Data for Name: espece; Type: TABLE DATA; Schema: observations; Owner: -
--

COPY observations.espece (es_id, es_nom_commun, es_nom_valide, es_nom_public) FROM stdin;
1	Baleine à bec de Cuvier	Ziphius cavirostris	Baleine
2	Baleine à bosse	Megaptera novaeangliae	Baleine
3	Cachalot	Physeter macrocephalus	Cachalot
4	Cachalot nain	Kogia simus	Cachalot
5	Cachalot pygmée	Kogia breviceps	Cachalot
6	Dauphin à bec étroit	Steno bredanensis	Dauphin
7	Dauphin à long bec	Stenella longirostris	Dauphin
8	Dauphin bleu et blanc	Stenella coeruleoalba	Dauphin
9	Dauphin commun	Delphinus delphis	Dauphin
10	Dauphin de Fraser	Lagenodelphis hosei	Dauphin
11	Dauphin de Risso	Grampus griseus	Dauphin
12	Dauphin tacheté	Stenella attenuata	Dauphin
13	Fausse-orque	Pseudorca crassidens	Dauphin
14	Globicéphale tropical	Globicephala macrorhynchus	Dauphin
15	Grand dauphin	Tursiops truncatus	Dauphin
16	Mésoplodon de blainville	Mesoplodon densirostris	Dauphin
17	Orque	Orchinus orca	Orque
18	Orque pygmée	Feresa attenuata	Dauphin
19	Péponocéphale	Peponocephala electra	Dauphin
20	Petit Rorqual Commun	Balaenoptera acutorostrata	Baleine
21	Rorqual bleu	Balaenoptera musculus	Baleine
22	Rorqual commun	Balaenoptera physalus	Baleine
23	Rorqual de Bryde	Balaenoptera edeni	Baleine
24	Rorqual de Rudolphi	Balaenoptera borealis	Baleine
25	Tortue verte	Chelonia mydas	Tortue
26	Tortue Imbriquée	Eretmochelys imbricata	Tortue
27	Tortue Caouanne	Caretta caretta	Tortue
28	Tortue olivatre	Lepidochelys olivacea	Tortue
29	Tortue luth	Dermochelys coriacea	Tortue
\.


--
-- Data for Name: nombres; Type: TABLE DATA; Schema: observations; Owner: -
--

COPY observations.nombres (code) FROM stdin;
1
2
3
4
5
6
7
8
9
10
11
12
13
14
15
16
17
18
19
20
21
22
23
24
25
26
27
28
29
30
31
32
33
34
35
36
37
38
39
40
41
42
43
44
45
46
47
48
49
50
51
52
53
54
55
56
57
58
59
60
61
62
63
64
65
66
67
68
69
70
71
72
73
74
75
76
77
78
79
80
81
82
83
84
85
86
87
88
89
90
91
92
93
94
95
96
97
98
99
100
101
102
103
104
105
106
107
108
109
110
111
112
113
114
115
116
117
118
119
120
121
122
123
124
125
126
127
128
129
130
131
132
133
134
135
136
137
138
139
140
141
142
143
144
145
146
147
148
149
150
\.


--
-- Data for Name: nomenclature; Type: TABLE DATA; Schema: observations; Owner: -
--

COPY observations.nomenclature (champ, code, valeur, description) FROM stdin;
distance_observation	0-30m	0-30m	\N
distance_observation	30-50m	30-50m	\N
distance_observation	50-100m	50-100m	\N
distance_observation	100m et +	100m et +	\N
mode_observation	En mer	En mer	\N
mode_observation	De la côte	De la côte	\N
mode_observation	En plongée	En plongée	\N
mode_observation	Autre	Autre	\N
type_navire	Kayak	Kayak	\N
type_navire	Pirogue	Pirogue	\N
type_navire	Bateau	Bateau	\N
type_navire	Paddle	Paddle	\N
type_navire	Autre	Autre	\N
profondeur_plongee	0-5m	0-5m	\N
profondeur_plongee	5-10m	5-10m	\N
profondeur_plongee	10-15m	10-15m	\N
profondeur_plongee	15m et +	15m et +	\N
etat_mer	Calme	Calme	\N
etat_mer	Peu agitée	Peu agitée	\N
etat_mer	Très agitée	Très agitée	\N
ob_type	MM	Mammifère Marin	\N
ob_type	ECH	Échouage	\N
ob_type	TORT	Tortue sur Terre	\N
ob_type	TORM	Tortue en mer	\N
ob_type	NID	Nid	\N
\.


--
-- Data for Name: observation; Type: TABLE DATA; Schema: observations; Owner: -
--

COPY observations.observation (id_obs, prenom, nom, date_obs, type_obs, espece, individu_isole, distance_observation, mode_observation, etat_mer, mm_charger_photo, geom) FROM stdin;
1	Doe	Francesco	2020-09-02 03:01:00	MM	2	f	0-30m	Autre	Calme	media/upload/observations/observation/mm_charger_photo/bosse.jpg	0101000020E6100000985E3968E79E62C078798CD02F4531C0
2	Doe	Jane	2020-09-04 08:05:00	ECH	27	f	0-30m	En mer	Calme	media/upload/observations/observation/mm_charger_photo/caretta.jpg	0101000020E61000002652398894B362C06F0E985B24AD31C0
5	Doe	John	2020-09-16 02:22:00	ECH	12	t	\N	De la côte	\N	media/upload/observations/observation/mm_charger_photo/dolphin.jpg	0101000020E610000019583908A6A962C09BEF85EC14A131C0
\.


--
-- Name: espece_es_id_seq; Type: SEQUENCE SET; Schema: observations; Owner: -
--

SELECT pg_catalog.setval('observations.espece_es_id_seq', 1, false);


--
-- Name: observation_id_obs_seq; Type: SEQUENCE SET; Schema: observations; Owner: -
--

SELECT pg_catalog.setval('observations.observation_id_obs_seq', 114, true);


--
-- Name: espece espece_pkey; Type: CONSTRAINT; Schema: observations; Owner: -
--

ALTER TABLE ONLY observations.espece
    ADD CONSTRAINT espece_pkey PRIMARY KEY (es_id);


--
-- Name: nombres nombres_pkey; Type: CONSTRAINT; Schema: observations; Owner: -
--

ALTER TABLE ONLY observations.nombres
    ADD CONSTRAINT nombres_pkey PRIMARY KEY (code);


--
-- Name: nomenclature nomenclature_pkey; Type: CONSTRAINT; Schema: observations; Owner: -
--

ALTER TABLE ONLY observations.nomenclature
    ADD CONSTRAINT nomenclature_pkey PRIMARY KEY (champ, code);


--
-- Name: observation observation_pkey; Type: CONSTRAINT; Schema: observations; Owner: -
--

ALTER TABLE ONLY observations.observation
    ADD CONSTRAINT observation_pkey PRIMARY KEY (id_obs);


--
-- Name: espece_es_nom_commun_idx; Type: INDEX; Schema: observations; Owner: -
--

CREATE INDEX espece_es_nom_commun_idx ON observations.espece USING btree (es_nom_commun);


--
-- Name: espece_es_nom_valide_idx; Type: INDEX; Schema: observations; Owner: -
--

CREATE INDEX espece_es_nom_valide_idx ON observations.espece USING btree (es_nom_valide);


--
-- Name: observation_date_obs_idx; Type: INDEX; Schema: observations; Owner: -
--

CREATE INDEX observation_date_obs_idx ON observations.observation USING btree (date_obs);


--
-- Name: observation_geom_idx; Type: INDEX; Schema: observations; Owner: -
--

CREATE INDEX observation_geom_idx ON observations.observation USING btree (geom);


--
-- Name: observation_type_obs_idx; Type: INDEX; Schema: observations; Owner: -
--

CREATE INDEX observation_type_obs_idx ON observations.observation USING btree (type_obs);


--
-- PostgreSQL database dump complete
--
