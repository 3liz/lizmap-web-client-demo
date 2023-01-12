--
-- PostgreSQL database dump
--

-- Dumped from database version 14.6 (Debian 14.6-1.pgdg110+1)
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

--
-- Name: demo_snapping; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA demo_snapping;


SET default_tablespace = '';


--
-- Name: point; Type: TABLE; Schema: demo_snapping; Owner: -
--

CREATE TABLE demo_snapping.point (
    id integer NOT NULL,
    title character varying(80),
    geom public.geometry(MultiPoint,4326)
);


--
-- Name: point_id_seq; Type: SEQUENCE; Schema: demo_snapping; Owner: -
--

CREATE SEQUENCE demo_snapping.point_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: point_id_seq; Type: SEQUENCE OWNED BY; Schema: demo_snapping; Owner: -
--

ALTER SEQUENCE demo_snapping.point_id_seq OWNED BY demo_snapping.point.id;


--
-- Name: point id; Type: DEFAULT; Schema: demo_snapping; Owner: -
--

ALTER TABLE ONLY demo_snapping.point ALTER COLUMN id SET DEFAULT nextval('demo_snapping.point_id_seq'::regclass);


--
-- Data for Name: point; Type: TABLE DATA; Schema: demo_snapping; Owner: -
--

COPY demo_snapping.point (id, title, geom) FROM stdin;
110	Bonjour, Si tu veux être mon ami tu peux placer un point à côté du mien :)	0104000020E61000000100000001010000007B081098410610401355769B58CF4540
\.


--
-- Name: point_id_seq; Type: SEQUENCE SET; Schema: demo_snapping; Owner: -
--

SELECT pg_catalog.setval('demo_snapping.point_id_seq', 209, true);


--
-- Name: point point_pkey; Type: CONSTRAINT; Schema: demo_snapping; Owner: -
--

ALTER TABLE ONLY demo_snapping.point
    ADD CONSTRAINT point_pkey PRIMARY KEY (id);


--
-- Name: point_geom_geom_idx; Type: INDEX; Schema: demo_snapping; Owner: -
--

CREATE INDEX point_geom_geom_idx ON demo_snapping.point USING gist (geom);


--
-- PostgreSQL database dump complete
--
