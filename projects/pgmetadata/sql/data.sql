--
-- PostgreSQL database dump
--

-- Dumped from database version 13.7 (Ubuntu 13.7-1.pgdg20.04+1)
-- Dumped by pg_dump version 13.7 (Ubuntu 13.7-1.pgdg20.04+1)

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
-- Name: pgmetadata; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgmetadata;


--
-- Name: SCHEMA pgmetadata; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA pgmetadata IS 'PgMetadata - contains tables for the QGIS plugin pg_metadata';


--
-- Name: pgmetadata_demo; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA pgmetadata_demo;


--
-- Name: calculate_fields_from_data(); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.calculate_fields_from_data() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
DECLARE
    test_target_table regclass;
    target_table text;
    test_geom_column record;
    test_rast_column record;
    geom_envelop geometry;
    geom_column_name text;
    rast_column_name text;
BEGIN

    -- table
    target_table = quote_ident(NEW.schema_name) || '.' || quote_ident(NEW.table_name);
    IF target_table IS NULL THEN
        RETURN NEW;
    END IF;

    -- Check if table exists
    EXECUTE 'SELECT to_regclass(' || quote_literal(target_table) ||')'
    INTO test_target_table
    ;
    IF test_target_table IS NULL THEN
        RAISE NOTICE 'pgmetadata - table does not exists: %', target_table;
        RETURN NEW;
    END IF;

    -- Date fields
    NEW.update_date = now();
    IF TG_OP = 'INSERT' THEN
        NEW.creation_date = now();
    END IF;

    -- Get table feature count
    EXECUTE 'SELECT COUNT(*) FROM ' || target_table
    INTO NEW.feature_count;
    -- RAISE NOTICE 'pgmetadata - % feature_count: %', target_table, NEW.feature_count;

    -- Check geometry properties: get data from geometry_columns and raster_columns
    EXECUTE
    ' SELECT *' ||
    ' FROM geometry_columns' ||
    ' WHERE f_table_schema=' || quote_literal(NEW.schema_name) ||
    ' AND f_table_name=' || quote_literal(NEW.table_name) ||
    ' LIMIT 1'
    INTO test_geom_column;

    IF to_regclass('raster_columns') is not null THEN
        EXECUTE
        ' SELECT *' ||
        ' FROM raster_columns' ||
        ' WHERE r_table_schema=' || quote_literal(NEW.schema_name) ||
        ' AND r_table_name=' || quote_literal(NEW.table_name) ||
        ' LIMIT 1'
        INTO test_rast_column;
    ELSE
        select null into test_rast_column;
    END IF;

    -- If the table has a geometry column, calculate field values
    IF test_geom_column IS NOT NULL THEN

        -- column name
        geom_column_name = test_geom_column.f_geometry_column;
        RAISE NOTICE 'pgmetadata - table % has a geometry column: %', target_table, geom_column_name;

        -- spatial_extent
        EXECUTE '
            SELECT CONCAT(
                min(ST_xmin("' || geom_column_name || '"))::text, '', '',
                max(ST_xmax("' || geom_column_name || '"))::text, '', '',
                min(ST_ymin("' || geom_column_name || '"))::text, '', '',
                max(ST_ymax("' || geom_column_name || '"))::text)
            FROM ' || target_table
        INTO NEW.spatial_extent;

        -- geom: convexhull from target table
        EXECUTE '
            SELECT ST_Transform(ST_ConvexHull(st_collect(ST_Force2d("' || geom_column_name || '"))), 4326)
            FROM ' || target_table
        INTO geom_envelop;

        -- Test if it's not a point or a line
        IF GeometryType(geom_envelop) != 'POLYGON' THEN
            EXECUTE '
                SELECT ST_SetSRID(ST_Buffer(ST_GeomFromText(''' || ST_ASTEXT(geom_envelop) || '''), 0.0001), 4326)'
            INTO NEW.geom;
        ELSE
            NEW.GEOM = geom_envelop;
        END IF;

        -- projection_authid
        EXECUTE '
            SELECT CONCAT(s.auth_name, '':'', ST_SRID(m."' || geom_column_name || '")::text)
            FROM ' || target_table || ' m, spatial_ref_sys s
            WHERE s.auth_srid = ST_SRID(m."' || geom_column_name || '")
            LIMIT 1'
        INTO NEW.projection_authid;

        -- projection_name
        -- TODO

        -- geometry_type
        NEW.geometry_type = test_geom_column.type;

    ELSIF test_rast_column is not null THEN

        -- column name
        rast_column_name = test_rast_column.r_raster_column;
        RAISE NOTICE 'pgmetadata - table % has a raster column: %', target_table, rast_column_name;

        -- spatial_extent
        EXECUTE 'SELECT CONCAT(ST_xmin($1)::text, '', '', ST_xmax($1)::text, '', '',
                               ST_ymin($1)::text, '', '', ST_ymax($1)::text)'
        INTO NEW.spatial_extent
        USING test_rast_column.extent;

        -- use extent (of whole table) from raster_columns catalog as envelope
        -- (union of convexhull of all rasters (tiles) in target table is too slow for big tables)
        EXECUTE 'SELECT ST_Transform($1, 4326)'
        INTO geom_envelop
        USING test_rast_column.extent;

        -- Test if it's not a point or a line
        IF GeometryType(geom_envelop) != 'POLYGON' THEN
            EXECUTE '
                SELECT ST_SetSRID(ST_Buffer(ST_GeomFromText(''' || ST_ASTEXT(geom_envelop) || '''), 0.0001), 4326)'
            INTO NEW.geom;
        ELSE
            NEW.GEOM = geom_envelop;
        END IF;

        -- projection_authid (use test_rast_column because querying table similar to vector layer is very slow)
        EXECUTE 'SELECT CONCAT(auth_name, '':'', $1) FROM spatial_ref_sys WHERE auth_srid = $1'
        INTO NEW.projection_authid
        USING test_rast_column.srid;

        -- geometry_type
        NEW.geometry_type = 'RASTER';

    ELSE
    -- No geometry column found: we need to erase values
            NEW.geom = NULL;
            NEW.projection_authid = NULL;
            NEW.geometry_type = NULL;
            NEW.spatial_extent = NULL;
    END IF;

    RETURN NEW;
END;
$_$;


--
-- Name: FUNCTION calculate_fields_from_data(); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.calculate_fields_from_data() IS 'Update some fields content when updating or inserting a line in pgmetadata.dataset table.';


--
-- Name: export_datasets_as_flat_table(text); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.export_datasets_as_flat_table(_locale text) RETURNS TABLE(uid uuid, table_name text, schema_name text, title text, abstract text, categories text, themes text, keywords text, spatial_level text, minimum_optimal_scale text, maximum_optimal_scale text, publication_date timestamp without time zone, publication_frequency text, license text, confidentiality text, feature_count integer, geometry_type text, projection_name text, projection_authid text, spatial_extent text, creation_date timestamp without time zone, update_date timestamp without time zone, data_last_update timestamp without time zone, links text, contacts text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    locale_exists boolean;
    sql_text text;
BEGIN

    -- Check if the _locale parameter corresponds to the available locales
    _locale = lower(_locale);
    SELECT _locale IN (SELECT locale FROM pgmetadata.v_locales)
    INTO locale_exists
    ;
    IF NOT locale_exists THEN
        _locale = 'en';
    END IF;

    -- Set locale
    -- We must use EXECUTE in order to have _locale to be correctly interpreted
    sql_text = concat('SET SESSION "pgmetadata.locale" = ', quote_literal(_locale));
    EXECUTE sql_text;

    -- Return content
    RETURN QUERY
    SELECT
    *
    FROM pgmetadata.v_export_table
    ;

END;
$$;


--
-- Name: FUNCTION export_datasets_as_flat_table(_locale text); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.export_datasets_as_flat_table(_locale text) IS 'Generate a flat representation of the datasets for a given locale.';


--
-- Name: generate_html_from_json(json, text); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.generate_html_from_json(_json_data json, _template_section text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    item record;
    html text;
BEGIN

    -- Get HTML template from html_template table
    SELECT content
    FROM pgmetadata.html_template AS h
    WHERE True
    AND section = _template_section
    INTO html
    ;
    IF html IS NULL THEN
        RETURN NULL;
    END IF;

    -- Get dataset item
    -- We transpose dataset record into rows such as
    -- col    | val
    -- id     | 1
    -- uid    | dfd3b73c-3cd3-40b7-b92d-aa0f625c86fe
    -- ...
    -- title  | My title
    -- For each row, we search and replace the [% "col" %] by val
    FOR item IN
        SELECT (line.d).key AS col, Coalesce((line.d).value, '') AS val
        FROM (
            SELECT json_each_text(_json_data) d
        ) AS line
    LOOP
        -- replace QGIS style field [% "my_field" %] by field value
        html = regexp_replace(
            html,
            concat('\[% *"?', item.col, '"? *%\]'),
            replace(item.val, '\', '\\'), -- escape backslashes in substitution string (\1...\9 refer to subexpressions)
            'g'
        )
        ;

    END LOOP;

    RETURN html;

END;
$$;


--
-- Name: FUNCTION generate_html_from_json(_json_data json, _template_section text); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.generate_html_from_json(_json_data json, _template_section text) IS 'Generate HTML content for the given JSON representation of a record and a given section, based on the template stored in the pgmetadata.html_template table. Template section controlled values are "main", "contact" and "link". If the corresponding line is not found in the pgmetadata.html_template table, NULL is returned.';


--
-- Name: get_dataset_item_html_content(text, text); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.get_dataset_item_html_content(_table_schema text, _table_name text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    html text;
BEGIN
    -- Call the new function with locale set to en
    SELECT pgmetadata.get_dataset_item_html_content(_table_schema, _table_name, 'en')
    INTO html;

    RETURN html;

END;
$$;


--
-- Name: FUNCTION get_dataset_item_html_content(_table_schema text, _table_name text); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.get_dataset_item_html_content(_table_schema text, _table_name text) IS 'Generate the metadata HTML content in English for the given table or NULL if no templates are stored in the pgmetadata.html_template table.';


--
-- Name: get_dataset_item_html_content(text, text, text); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.get_dataset_item_html_content(_table_schema text, _table_name text, _locale text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    locale_exists boolean;
    item record;
    dataset_rec record;
    sql_text text;
    json_data json;
    html text;
    html_contact text;
    html_link text;
    html_main text;
BEGIN
    -- Check if dataset exists
    SELECT *
    FROM pgmetadata.dataset
    WHERE True
    AND schema_name = _table_schema
    AND table_name = _table_name
    LIMIT 1
    INTO dataset_rec
    ;

    IF dataset_rec.id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Check if the _locale parameter corresponds to the available locales
    _locale = lower(_locale);
    SELECT _locale IN (SELECT locale FROM pgmetadata.v_locales)
    INTO locale_exists
    ;
    IF NOT locale_exists THEN
        _locale = 'en';
    END IF;

    -- Set locale
    -- We must use EXECUTE in order to have _locale to be correctly interpreted
    sql_text = concat('SET SESSION "pgmetadata.locale" = ', quote_literal(_locale));
    EXECUTE sql_text;

    -- Contacts
    html_contact = '';
    FOR json_data IN
        WITH a AS (
            SELECT *
            FROM pgmetadata.v_contact
            WHERE True
            AND schema_name = _table_schema
            AND table_name = _table_name
        )
        SELECT row_to_json(a.*)
        FROM a
    LOOP
        html_contact = concat(
            html_contact, '
            ',
            pgmetadata.generate_html_from_json(json_data, 'contact')
        );
    END LOOP;
    -- RAISE NOTICE 'html_contact: %', html_contact;

    -- Links
    html_link = '';
    FOR json_data IN
        WITH a AS (
            SELECT *
            FROM pgmetadata.v_link
            WHERE True
            AND schema_name = _table_schema
            AND table_name = _table_name
        )
        SELECT row_to_json(a.*)
        FROM a
    LOOP
        html_link = concat(
            html_link, '
            ',
            pgmetadata.generate_html_from_json(json_data, 'link')
        );
    END LOOP;
    --RAISE NOTICE 'html_link: %', html_link;

    -- Main
    html_main = '';
    WITH a AS (
        SELECT *
        FROM pgmetadata.v_dataset
        WHERE True
        AND schema_name = _table_schema
        AND table_name = _table_name
    )
    SELECT row_to_json(a.*)
    FROM a
    INTO json_data
    ;
    html_main = pgmetadata.generate_html_from_json(json_data, 'main');
    -- RAISE NOTICE 'html_main: %', html_main;

    IF html_main IS NULL THEN
        RETURN NULL;
    END IF;

    html = html_main;

    -- add contacts: [% "meta_contacts" %]
    html = regexp_replace(
        html,
        concat('\[% *"?meta_contacts"? *%\]'),
        coalesce(replace(html_contact, '\', '\\'), ''), -- escape backslashes in substitution string (\1...\9 refer to subexpressions)
        'g'
    );

    -- add links [% "meta_links" %]
    html = regexp_replace(
        html,
        concat('\[% *"?meta_links"? *%\]'),
        coalesce(replace(html_link, '\', '\\'), ''), -- escape backslashes in substitution string (\1...\9 refer to subexpressions)
        'g'
    );

    RETURN html;

END;
$$;


--
-- Name: FUNCTION get_dataset_item_html_content(_table_schema text, _table_name text, _locale text); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.get_dataset_item_html_content(_table_schema text, _table_name text, _locale text) IS 'Generate the metadata HTML content for the given table and given language or NULL if no templates are stored in the pgmetadata.html_template table.';


--
-- Name: get_datasets_as_dcat_xml(text); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.get_datasets_as_dcat_xml(_locale text) RETURNS TABLE(schema_name text, table_name text, uid uuid, dataset xml)
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Call the new function
    RETURN QUERY
    SELECT
    *
    FROM pgmetadata.get_datasets_as_dcat_xml(
        _locale,
        -- passing NULL means no filter
        NULL
    )
    ;

END;
$$;


--
-- Name: FUNCTION get_datasets_as_dcat_xml(_locale text); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.get_datasets_as_dcat_xml(_locale text) IS 'Get the datasets records as XML DCAT datasets for the given locale. All datasets are returned';


--
-- Name: get_datasets_as_dcat_xml(text, uuid[]); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.get_datasets_as_dcat_xml(_locale text, uids uuid[]) RETURNS TABLE(schema_name text, table_name text, uid uuid, dataset xml)
    LANGUAGE plpgsql
    AS $$
DECLARE
    locale_exists boolean;
    sql_text text;
BEGIN

    -- Check if the _locale parameter corresponds to the available locales
    _locale = lower(_locale);
    SELECT _locale IN (SELECT locale FROM pgmetadata.v_locales)
    INTO locale_exists
    ;
    IF NOT locale_exists THEN
        _locale = 'en';
    END IF;

    -- Set locale
    -- We must use EXECUTE in order to have _locale to be correctly interpreted
    sql_text = concat('SET SESSION "pgmetadata.locale" = ', quote_literal(_locale));
    EXECUTE sql_text;

    -- Return content
    IF uids IS NOT NULL THEN
        RETURN QUERY
        SELECT
        *
        FROM pgmetadata.v_dataset_as_dcat AS d
        WHERE d.uid = ANY (uids)
        ;
    ELSE
        RETURN QUERY
        SELECT
        *
        FROM pgmetadata.v_dataset_as_dcat AS d
        ;
    END IF;

END;
$$;


--
-- Name: FUNCTION get_datasets_as_dcat_xml(_locale text, uids uuid[]); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.get_datasets_as_dcat_xml(_locale text, uids uuid[]) IS 'Get the datasets records as XML DCAT datasets for the given locale. Datasets are filtered by the given array of uids. IF uids is NULL, no filter is used and all datasets are returned';


--
-- Name: refresh_dataset_calculated_fields(); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.refresh_dataset_calculated_fields() RETURNS void
    LANGUAGE plpgsql
    AS $$ BEGIN 	UPDATE pgmetadata.dataset SET geom = NULL; END; $$;


--
-- Name: FUNCTION refresh_dataset_calculated_fields(); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.refresh_dataset_calculated_fields() IS 'Force the calculation of spatial related fields in dataset table by updating all lines, which will trigger the function calculate_fields_from_data';


--
-- Name: update_postgresql_table_comment(text, text, text, text); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.update_postgresql_table_comment(table_schema text, table_name text, table_comment text, table_type text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    sql_text text;
BEGIN

    BEGIN
        sql_text = 'COMMENT ON ' || replace(quote_literal(table_type), '''', '') || ' ' || quote_ident(table_schema) || '.' || quote_ident(table_name) || ' IS ' || quote_literal(table_comment) ;
        EXECUTE sql_text;
        RAISE NOTICE 'Comment updated for %', quote_ident(table_schema) || '.' || quote_ident(table_name) ;
        RETURN True;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'ERROR - Failed updated comment for table %', quote_ident(table_schema) || '.' || quote_ident(table_name);
        RETURN False;
    END;

    RETURN True;
END;
$$;


--
-- Name: FUNCTION update_postgresql_table_comment(table_schema text, table_name text, table_comment text, table_type text); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.update_postgresql_table_comment(table_schema text, table_name text, table_comment text, table_type text) IS 'Update the PostgreSQL comment of a table by giving table schema, name and comment
Example: if you need to update the comments for all the items listed by pgmetadata.v_table_comment_from_metadata:

    SELECT
    v.table_schema,
    v.table_name,
    pgmetadata.update_postgresql_table_comment(
        v.table_schema,
        v.table_name,
        v.table_comment,
        v.table_type
    ) AS comment_updated
    FROM pgmetadata.v_table_comment_from_metadata AS v

    ';


--
-- Name: update_table_comment_from_dataset(); Type: FUNCTION; Schema: pgmetadata; Owner: -
--

CREATE FUNCTION pgmetadata.update_table_comment_from_dataset() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    is_updated bool;
BEGIN
    SELECT pgmetadata.update_postgresql_table_comment(
        v.table_schema,
        v.table_name,
        v.table_comment,
        v.table_type
    )
    FROM pgmetadata.v_table_comment_from_metadata AS v
    WHERE True
    AND v.table_schema = NEW.schema_name
    AND v.table_name = NEW.table_name
    INTO is_updated
    ;

    RETURN NEW;
END;
$$;


--
-- Name: FUNCTION update_table_comment_from_dataset(); Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON FUNCTION pgmetadata.update_table_comment_from_dataset() IS 'Update the PostgreSQL table comment when updating or inserting a line in pgmetadata.dataset table. Comment is taken from the view pgmetadata.v_table_comment_from_metadata.';


SET default_tablespace = '';


--
-- Name: contact; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.contact (
    id integer NOT NULL,
    name text NOT NULL,
    organisation_name text NOT NULL,
    organisation_unit text,
    email text,
    phone text
);


--
-- Name: TABLE contact; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.contact IS 'List of contacts related to the published datasets.';


--
-- Name: COLUMN contact.id; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.contact.id IS 'Internal automatic integer ID';


--
-- Name: COLUMN contact.name; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.contact.name IS 'Full name of the contact';


--
-- Name: COLUMN contact.organisation_name; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.contact.organisation_name IS 'Organisation name. E.g. ACME';


--
-- Name: COLUMN contact.organisation_unit; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.contact.organisation_unit IS 'Organisation unit name. E.g. GIS unit';


--
-- Name: COLUMN contact.email; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.contact.email IS 'Email address';


--
-- Name: COLUMN contact.phone; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.contact.phone IS 'Phone number';


--
-- Name: contact_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: contact_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.contact_id_seq OWNED BY pgmetadata.contact.id;


--
-- Name: dataset; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.dataset (
    id integer NOT NULL,
    uid uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    table_name text NOT NULL,
    schema_name text NOT NULL,
    title text NOT NULL,
    abstract text NOT NULL,
    categories text[],
    keywords text,
    spatial_level text,
    minimum_optimal_scale integer,
    maximum_optimal_scale integer,
    publication_date timestamp without time zone DEFAULT now(),
    publication_frequency text,
    license text,
    confidentiality text,
    feature_count integer,
    geometry_type text,
    projection_name text,
    projection_authid text,
    spatial_extent text,
    creation_date timestamp without time zone DEFAULT now() NOT NULL,
    update_date timestamp without time zone DEFAULT now(),
    geom public.geometry(Polygon,4326),
    data_last_update timestamp without time zone,
    themes text[]
);


--
-- Name: TABLE dataset; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.dataset IS 'Main table for storing dataset about PostgreSQL vector layers.';


--
-- Name: COLUMN dataset.id; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.id IS 'Internal automatic integer ID';


--
-- Name: COLUMN dataset.uid; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.uid IS 'Unique identifier of the data. E.g. 89e3dde9-3850-c211-5045-b5b09aa1da9a';


--
-- Name: COLUMN dataset.table_name; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.table_name IS 'Name of the related table in the database';


--
-- Name: COLUMN dataset.schema_name; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.schema_name IS 'Name of the related schema in the database';


--
-- Name: COLUMN dataset.title; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.title IS 'Title of the data';


--
-- Name: COLUMN dataset.abstract; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.abstract IS 'Full description of the data';


--
-- Name: COLUMN dataset.categories; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.categories IS 'List of categories';


--
-- Name: COLUMN dataset.keywords; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.keywords IS 'List of keywords separated by comma. Ex: environment, paris, trees';


--
-- Name: COLUMN dataset.spatial_level; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.spatial_level IS 'Spatial level of the data. E.g. city, country, street';


--
-- Name: COLUMN dataset.minimum_optimal_scale; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.minimum_optimal_scale IS 'Minimum optimal scale denominator to view the data. E.g. 100000 for 1/100000. Most "zoomed out".';


--
-- Name: COLUMN dataset.maximum_optimal_scale; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.maximum_optimal_scale IS 'Maximum optimal scale denominator to view the data. E.g. 2000 for 1/2000. Most "zoomed in".';


--
-- Name: COLUMN dataset.publication_date; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.publication_date IS 'Date of publication of the data';


--
-- Name: COLUMN dataset.publication_frequency; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.publication_frequency IS 'Frequency of publication: how often the data is published.';


--
-- Name: COLUMN dataset.license; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.license IS 'License. E.g. Public domain';


--
-- Name: COLUMN dataset.confidentiality; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.confidentiality IS 'Confidentiality of the data.';


--
-- Name: COLUMN dataset.feature_count; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.feature_count IS 'Number of features of the data';


--
-- Name: COLUMN dataset.geometry_type; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.geometry_type IS 'Geometry type. E.g. Polygon';


--
-- Name: COLUMN dataset.projection_name; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.projection_name IS 'Projection name of the dataset. E.g. WGS 84 - Geographic';


--
-- Name: COLUMN dataset.projection_authid; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.projection_authid IS 'Projection auth id. E.g. EPSG:4326';


--
-- Name: COLUMN dataset.spatial_extent; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.spatial_extent IS 'Spatial extent of the data. xmin,ymin,xmax,ymax.';


--
-- Name: COLUMN dataset.creation_date; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.creation_date IS 'Date of creation of the dataset item';


--
-- Name: COLUMN dataset.update_date; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.update_date IS 'Date of update of the dataset item';


--
-- Name: COLUMN dataset.geom; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.geom IS 'Geometry defining the extent of the data. Can be any polygon.';


--
-- Name: COLUMN dataset.data_last_update; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.data_last_update IS 'Date of the last modification of the target data (not on the dataset item line)';


--
-- Name: COLUMN dataset.themes; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset.themes IS 'List of themes';


--
-- Name: dataset_contact; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.dataset_contact (
    id integer NOT NULL,
    fk_id_contact integer NOT NULL,
    fk_id_dataset integer NOT NULL,
    contact_role text NOT NULL
);


--
-- Name: TABLE dataset_contact; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.dataset_contact IS 'Pivot table between dataset and contacts.';


--
-- Name: COLUMN dataset_contact.id; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset_contact.id IS 'Internal automatic integer ID';


--
-- Name: COLUMN dataset_contact.fk_id_contact; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset_contact.fk_id_contact IS 'Id of the contact item';


--
-- Name: COLUMN dataset_contact.fk_id_dataset; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset_contact.fk_id_dataset IS 'Id of the dataset item';


--
-- Name: COLUMN dataset_contact.contact_role; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.dataset_contact.contact_role IS 'Role of the contact for the specified dataset item. E.g. owner, distributor';


--
-- Name: dataset_contact_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.dataset_contact_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dataset_contact_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.dataset_contact_id_seq OWNED BY pgmetadata.dataset_contact.id;


--
-- Name: dataset_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.dataset_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dataset_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.dataset_id_seq OWNED BY pgmetadata.dataset.id;


--
-- Name: glossary; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.glossary (
    id integer NOT NULL,
    field text NOT NULL,
    code text NOT NULL,
    label_en text NOT NULL,
    description_en text,
    item_order smallint,
    label_fr text,
    description_fr text,
    label_it text,
    description_it text,
    label_es text,
    description_es text,
    label_de text,
    description_de text
);


--
-- Name: TABLE glossary; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.glossary IS 'List of labels and words used as labels for stored data';


--
-- Name: COLUMN glossary.id; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.glossary.id IS 'Internal automatic integer ID';


--
-- Name: COLUMN glossary.field; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.glossary.field IS 'Field name';


--
-- Name: COLUMN glossary.code; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.glossary.code IS 'Item code';


--
-- Name: COLUMN glossary.label_en; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.glossary.label_en IS 'Item label';


--
-- Name: COLUMN glossary.description_en; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.glossary.description_en IS 'Description';


--
-- Name: COLUMN glossary.item_order; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.glossary.item_order IS 'Display order';


--
-- Name: glossary_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.glossary_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: glossary_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.glossary_id_seq OWNED BY pgmetadata.glossary.id;


--
-- Name: html_template; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.html_template (
    id integer NOT NULL,
    section text NOT NULL,
    content text,
    CONSTRAINT html_template_section_check CHECK ((section = ANY (ARRAY['main'::text, 'contact'::text, 'link'::text])))
);


--
-- Name: TABLE html_template; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.html_template IS 'This table contains the HTML templates for the main metadata sheet, and one for the contacts and links. Contacts and links templates are used to compute a unique contact or link HTML representation.';


--
-- Name: html_template_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.html_template_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: html_template_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.html_template_id_seq OWNED BY pgmetadata.html_template.id;


--
-- Name: link; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.link (
    id integer NOT NULL,
    name text NOT NULL,
    type text NOT NULL,
    url text NOT NULL,
    description text,
    format text,
    mime text,
    size integer,
    fk_id_dataset integer NOT NULL
);


--
-- Name: TABLE link; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.link IS 'List of links related to the published datasets.';


--
-- Name: COLUMN link.id; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.id IS 'Internal automatic integer ID';


--
-- Name: COLUMN link.name; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.name IS 'Name of the link';


--
-- Name: COLUMN link.type; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.type IS 'Type of the link. E.g. https, git, OGC:WFS';


--
-- Name: COLUMN link.url; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.url IS 'Full URL';


--
-- Name: COLUMN link.description; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.description IS 'Description';


--
-- Name: COLUMN link.format; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.format IS 'Format.';


--
-- Name: COLUMN link.mime; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.mime IS 'Mime type';


--
-- Name: COLUMN link.size; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.size IS 'Size of the target';


--
-- Name: COLUMN link.fk_id_dataset; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.link.fk_id_dataset IS 'Id of the dataset item';


--
-- Name: link_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.link_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: link_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.link_id_seq OWNED BY pgmetadata.link.id;


--
-- Name: qgis_plugin; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.qgis_plugin (
    id integer NOT NULL,
    version text NOT NULL,
    version_date date NOT NULL,
    status smallint NOT NULL
);


--
-- Name: TABLE qgis_plugin; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.qgis_plugin IS 'Version and date of the database structure. Useful for database structure and glossary data migrations between the plugin versions by the QGIS plugin pg_metadata';


--
-- Name: theme; Type: TABLE; Schema: pgmetadata; Owner: -
--

CREATE TABLE pgmetadata.theme (
    id integer NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    description text
);


--
-- Name: TABLE theme; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON TABLE pgmetadata.theme IS 'List of themes related to the published datasets.';


--
-- Name: COLUMN theme.id; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.theme.id IS 'Internal automatic integer ID';


--
-- Name: COLUMN theme.code; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.theme.code IS 'Code Of the theme';


--
-- Name: COLUMN theme.label; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.theme.label IS 'Label of the theme';


--
-- Name: COLUMN theme.description; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON COLUMN pgmetadata.theme.description IS 'Description of the theme';


--
-- Name: theme_id_seq; Type: SEQUENCE; Schema: pgmetadata; Owner: -
--

CREATE SEQUENCE pgmetadata.theme_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: theme_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata; Owner: -
--

ALTER SEQUENCE pgmetadata.theme_id_seq OWNED BY pgmetadata.theme.id;


--
-- Name: v_glossary; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_glossary AS
 WITH one AS (
         SELECT glossary.field,
            glossary.code,
            json_build_object('label', json_build_object('en', glossary.label_en, 'fr', COALESCE(NULLIF(glossary.label_fr, ''::text), glossary.label_en, ''::text), 'it', COALESCE(NULLIF(glossary.label_it, ''::text), glossary.label_en, ''::text), 'es', COALESCE(NULLIF(glossary.label_es, ''::text), glossary.label_en, ''::text), 'de', COALESCE(NULLIF(glossary.label_de, ''::text), glossary.label_en, ''::text)), 'description', json_build_object('en', glossary.description_en, 'fr', COALESCE(NULLIF(glossary.description_fr, ''::text), glossary.description_en, ''::text), 'it', COALESCE(NULLIF(glossary.description_it, ''::text), glossary.description_en, ''::text), 'es', COALESCE(NULLIF(glossary.description_es, ''::text), glossary.description_en, ''::text), 'de', COALESCE(NULLIF(glossary.description_de, ''::text), glossary.description_en, ''::text))) AS dict
           FROM pgmetadata.glossary
        ), two AS (
         SELECT one.field,
            json_object_agg(one.code, one.dict) AS dict
           FROM one
          GROUP BY one.field
        )
 SELECT json_object_agg(two.field, two.dict) AS dict
   FROM two;


--
-- Name: VIEW v_glossary; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_glossary IS 'View transforming the glossary content into a JSON helping to localize a label or description by fetching directly the corresponding item. Ex: SET SESSION "pgmetadata.locale" = ''fr''; WITH glossary AS (SELECT dict FROM pgmetadata.v_glossary) SELECT (dict->''contact.contact_role''->''OW''->''label''->''fr'')::text AS label FROM glossary;';


--
-- Name: v_contact; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_contact AS
 WITH glossary AS (
         SELECT COALESCE(current_setting('pgmetadata.locale'::text, true), 'en'::text) AS locale,
            v_glossary.dict
           FROM pgmetadata.v_glossary
        )
 SELECT d.table_name,
    d.schema_name,
    c.name,
    c.organisation_name,
    c.organisation_unit,
    ((((glossary.dict -> 'contact.contact_role'::text) -> dc.contact_role) -> 'label'::text) ->> glossary.locale) AS contact_role,
    dc.contact_role AS contact_role_code,
    c.email,
    c.phone
   FROM glossary,
    ((pgmetadata.dataset_contact dc
     JOIN pgmetadata.dataset d ON ((d.id = dc.fk_id_dataset)))
     JOIN pgmetadata.contact c ON ((dc.fk_id_contact = c.id)))
  WHERE true
  ORDER BY dc.id;


--
-- Name: VIEW v_contact; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_contact IS 'Formatted version of contact data, with all the codes replaced by corresponding labels taken from pgmetadata.glossary. Used in the function in charge of building the HTML metadata content. The localized version of labels and descriptions are taken considering the session setting ''pgmetadata.locale''. For example with: SET SESSION "pgmetadata.locale" = ''fr''; ';


--
-- Name: v_dataset; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_dataset AS
 WITH glossary AS (
         SELECT COALESCE(current_setting('pgmetadata.locale'::text, true), 'en'::text) AS locale,
            v_glossary.dict
           FROM pgmetadata.v_glossary
        ), s AS (
         SELECT d.id,
            d.uid,
            d.table_name,
            d.schema_name,
            d.title,
            d.abstract,
            d.categories,
            d.themes,
            d.keywords,
            d.spatial_level,
            d.minimum_optimal_scale,
            d.maximum_optimal_scale,
            d.publication_date,
            d.publication_frequency,
            d.license,
            d.confidentiality,
            d.feature_count,
            d.geometry_type,
            d.projection_name,
            d.projection_authid,
            d.spatial_extent,
            d.creation_date,
            d.update_date,
            d.data_last_update,
            d.geom,
            cat.cat,
            theme.theme
           FROM ((pgmetadata.dataset d
             LEFT JOIN LATERAL unnest(d.categories) cat(cat) ON (true))
             LEFT JOIN LATERAL unnest(d.themes) theme(theme) ON (true))
          WHERE true
          ORDER BY d.id
        ), ss AS (
         SELECT s.id,
            s.uid,
            s.table_name,
            s.schema_name,
            s.title,
            s.abstract,
            ((((glossary.dict -> 'dataset.categories'::text) -> s.cat) -> 'label'::text) ->> glossary.locale) AS cat,
            gtheme.label AS theme,
            s.keywords,
            s.spatial_level,
            ('1/'::text || s.minimum_optimal_scale) AS minimum_optimal_scale,
            ('1/'::text || s.maximum_optimal_scale) AS maximum_optimal_scale,
            s.publication_date,
            ((((glossary.dict -> 'dataset.publication_frequency'::text) -> s.publication_frequency) -> 'label'::text) ->> glossary.locale) AS publication_frequency,
            ((((glossary.dict -> 'dataset.license'::text) -> s.license) -> 'label'::text) ->> glossary.locale) AS license,
            ((((glossary.dict -> 'dataset.confidentiality'::text) -> s.confidentiality) -> 'label'::text) ->> glossary.locale) AS confidentiality,
            s.feature_count,
            s.geometry_type,
            (regexp_split_to_array((rs.srtext)::text, '"'::text))[2] AS projection_name,
            s.projection_authid,
            s.spatial_extent,
            s.creation_date,
            s.update_date,
            s.data_last_update
           FROM glossary,
            ((s
             LEFT JOIN pgmetadata.theme gtheme ON ((gtheme.code = s.theme)))
             LEFT JOIN public.spatial_ref_sys rs ON ((concat(rs.auth_name, ':', rs.auth_srid) = s.projection_authid)))
        )
 SELECT ss.id,
    ss.uid,
    ss.table_name,
    ss.schema_name,
    ss.title,
    ss.abstract,
    string_agg(DISTINCT ss.cat, ', '::text ORDER BY ss.cat) AS categories,
    string_agg(DISTINCT ss.theme, ', '::text ORDER BY ss.theme) AS themes,
    ss.keywords,
    ss.spatial_level,
    ss.minimum_optimal_scale,
    ss.maximum_optimal_scale,
    ss.publication_date,
    ss.publication_frequency,
    ss.license,
    ss.confidentiality,
    ss.feature_count,
    ss.geometry_type,
    ss.projection_name,
    ss.projection_authid,
    ss.spatial_extent,
    ss.creation_date,
    ss.update_date,
    ss.data_last_update
   FROM ss
  GROUP BY ss.id, ss.uid, ss.table_name, ss.schema_name, ss.title, ss.abstract, ss.keywords, ss.spatial_level, ss.minimum_optimal_scale, ss.maximum_optimal_scale, ss.publication_date, ss.publication_frequency, ss.license, ss.confidentiality, ss.feature_count, ss.geometry_type, ss.projection_name, ss.projection_authid, ss.spatial_extent, ss.creation_date, ss.update_date, ss.data_last_update;


--
-- Name: VIEW v_dataset; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_dataset IS 'Formatted version of dataset data, with all the codes replaced by corresponding labels taken from pgmetadata.glossary. Used in the function in charge of building the HTML metadata content.';


--
-- Name: v_dataset_as_dcat; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_dataset_as_dcat AS
 WITH glossary AS (
         SELECT COALESCE(current_setting('pgmetadata.locale'::text, true), 'en'::text) AS locale,
            v_glossary.dict
           FROM pgmetadata.v_glossary
        )
 SELECT d.schema_name,
    d.table_name,
    d.uid,
    XMLELEMENT(NAME "dcat:dataset", XMLELEMENT(NAME "dcat:Dataset", XMLFOREST(d.uid AS "dct:identifier", d.title AS "dct:title", d.abstract AS "dct:description", COALESCE(current_setting('pgmetadata.locale'::text, true), 'en'::text) AS "dct:language", ((((glossary.dict -> 'dataset.license'::text) -> d.license) -> 'label'::text) ->> glossary.locale) AS "dct:license", ((((glossary.dict -> 'dataset.confidentiality'::text) -> d.confidentiality) -> 'label'::text) ->> glossary.locale) AS "dct:rights", ((((glossary.dict -> 'dataset.publication_frequency'::text) -> d.publication_frequency) -> 'label'::text) ->> glossary.locale) AS "dct:accrualPeriodicity", public.st_asgeojson(d.geom) AS "dct:spatial"), XMLELEMENT(NAME "dct:created", XMLATTRIBUTES('http://www.w3.org/2001/XMLSchema#dateTime' AS "rdf:datatype"), d.creation_date), XMLELEMENT(NAME "dct:issued", XMLATTRIBUTES('http://www.w3.org/2001/XMLSchema#dateTime' AS "rdf:datatype"), d.publication_date), XMLELEMENT(NAME "dct:modified", XMLATTRIBUTES('http://www.w3.org/2001/XMLSchema#dateTime' AS "rdf:datatype"), d.update_date), ( SELECT xmlagg(XMLCONCAT(XMLELEMENT(NAME "dcat:contactPoint", XMLELEMENT(NAME "vcard:Organization", XMLELEMENT(NAME "vcard:fn", btrim(concat(c.name, ' - ', c.organisation_name, ((' ('::text || c.organisation_unit) || ')'::text)))), XMLELEMENT(NAME "vcard:hasEmail", XMLATTRIBUTES(c.email AS "rdf:resource"), c.email))), XMLELEMENT(NAME "dct:creator", XMLELEMENT(NAME "foaf:Organization", XMLELEMENT(NAME "foaf:name", btrim(concat(c.name, ' - ', c.organisation_name, ((' ('::text || c.organisation_unit) || ')'::text)))), XMLELEMENT(NAME "foaf:mbox", c.email))))) AS xmlagg
           FROM (pgmetadata.contact c
             JOIN pgmetadata.dataset_contact dc ON (((dc.contact_role = 'OW'::text) AND (dc.fk_id_dataset = d.id) AND (dc.fk_id_contact = c.id))))), ( SELECT xmlagg(XMLELEMENT(NAME "dct:publisher", XMLELEMENT(NAME "foaf:Organization", XMLELEMENT(NAME "foaf:name", btrim(concat(c.name, ' - ', c.organisation_name, ((' ('::text || c.organisation_unit) || ')'::text)))), XMLELEMENT(NAME "foaf:mbox", c.email)))) AS xmlagg
           FROM (pgmetadata.contact c
             JOIN pgmetadata.dataset_contact dc ON (((dc.contact_role = 'DI'::text) AND (dc.fk_id_dataset = d.id) AND (dc.fk_id_contact = c.id))))), ( SELECT xmlagg(XMLELEMENT(NAME "dcat:distribution", XMLELEMENT(NAME "dcat:Distribution", XMLFOREST(l.name AS "dct:title", l.description AS "dct:description", l.url AS "dcat:downloadURL", ((((glossary.dict -> 'link.mime'::text) -> l.mime) -> 'label'::text) ->> glossary.locale) AS "dcat:mediaType", COALESCE(l.format, ((((glossary.dict -> 'link.type'::text) -> l.type) -> 'label'::text) ->> glossary.locale)) AS "dct:format", l.size AS "dct:bytesize", ((((glossary.dict -> 'dataset.license'::text) -> d.license) -> 'label'::text) ->> glossary.locale) AS "dct:license")))) AS xmlagg
           FROM pgmetadata.link l
          WHERE (l.fk_id_dataset = d.id)), ( SELECT xmlagg(XMLELEMENT(NAME "dcat:keyword", btrim(kw.kw))) AS xmlagg
           FROM unnest(regexp_split_to_array(d.keywords, ','::text)) kw(kw)), ( SELECT xmlagg(XMLELEMENT(NAME "dcat:theme", th.label)) AS xmlagg
           FROM pgmetadata.theme th,
            unnest(d.themes) cat(cat)
          WHERE (th.code = cat.cat)), ( SELECT xmlagg(XMLELEMENT(NAME "dcat:theme", ((((glossary.dict -> 'dataset.categories'::text) -> cat.cat) -> 'label'::text) ->> glossary.locale))) AS xmlagg
           FROM unnest(d.categories) cat(cat)))) AS dataset
   FROM glossary,
    pgmetadata.dataset d;


--
-- Name: VIEW v_dataset_as_dcat; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_dataset_as_dcat IS 'DCAT - View which formats the datasets AS DCAT XML record objects';


--
-- Name: v_link; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_link AS
 WITH glossary AS (
         SELECT COALESCE(current_setting('pgmetadata.locale'::text, true), 'en'::text) AS locale,
            v_glossary.dict
           FROM pgmetadata.v_glossary
        )
 SELECT l.id,
    d.table_name,
    d.schema_name,
    l.name,
    l.type,
    ((((glossary.dict -> 'link.type'::text) -> l.type) -> 'label'::text) ->> glossary.locale) AS type_label,
    l.url,
    l.description,
    l.format,
    l.mime,
    ((((glossary.dict -> 'link.mime'::text) -> l.mime) -> 'label'::text) ->> glossary.locale) AS mime_label,
    l.size
   FROM glossary,
    (pgmetadata.link l
     JOIN pgmetadata.dataset d ON ((d.id = l.fk_id_dataset)))
  WHERE true
  ORDER BY l.id;


--
-- Name: VIEW v_link; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_link IS 'Formatted version of link data, with all the codes replaced by corresponding labels taken from pgmetadata.glossary. Used in the function in charge of building the HTML metadata content.';


--
-- Name: v_export_table; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_export_table AS
 SELECT d.uid,
    d.table_name,
    d.schema_name,
    d.title,
    d.abstract,
    d.categories,
    d.themes,
    d.keywords,
    d.spatial_level,
    d.minimum_optimal_scale,
    d.maximum_optimal_scale,
    d.publication_date,
    d.publication_frequency,
    d.license,
    d.confidentiality,
    d.feature_count,
    d.geometry_type,
    d.projection_name,
    d.projection_authid,
    d.spatial_extent,
    d.creation_date,
    d.update_date,
    d.data_last_update,
    string_agg(((l.name || ': '::text) || l.url), ', '::text) AS links,
    string_agg((((((c.name || ' ('::text) || c.organisation_name) || ')'::text) || ' - '::text) || c.contact_role), ', '::text) AS contacts
   FROM ((pgmetadata.v_dataset d
     LEFT JOIN pgmetadata.v_link l ON (((l.table_name = d.table_name) AND (l.schema_name = d.schema_name))))
     LEFT JOIN pgmetadata.v_contact c ON (((c.table_name = d.table_name) AND (c.schema_name = d.schema_name))))
  GROUP BY d.uid, d.table_name, d.schema_name, d.title, d.abstract, d.categories, d.themes, d.keywords, d.spatial_level, d.minimum_optimal_scale, d.maximum_optimal_scale, d.publication_date, d.publication_frequency, d.license, d.confidentiality, d.feature_count, d.geometry_type, d.projection_name, d.projection_authid, d.spatial_extent, d.creation_date, d.update_date, d.data_last_update
  ORDER BY d.schema_name, d.table_name;


--
-- Name: VIEW v_export_table; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_export_table IS 'Generate a flat representation of the datasets. Links and contacts are grouped in one column each';


--
-- Name: v_locales; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_locales AS
 SELECT 'en'::text AS locale
UNION
 SELECT replace((columns.column_name)::text, 'label_'::text, ''::text) AS locale
   FROM information_schema.columns
  WHERE (((columns.table_schema)::text = 'pgmetadata'::text) AND ((columns.table_name)::text = 'glossary'::text) AND ((columns.column_name)::text ~~ 'label_%'::text))
  ORDER BY 1;


--
-- Name: VIEW v_locales; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_locales IS 'Lists the locales available in the glossary, by listing the columns label_xx of the table pgmetadata.glossary';


--
-- Name: v_orphan_dataset_items; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_orphan_dataset_items AS
 SELECT row_number() OVER () AS id,
    d.schema_name,
    d.table_name
   FROM (pgmetadata.dataset d
     LEFT JOIN information_schema.tables t ON (((d.schema_name = (t.table_schema)::text) AND (d.table_name = (t.table_name)::text))))
  WHERE (t.table_name IS NULL)
  ORDER BY d.schema_name, d.table_name;


--
-- Name: VIEW v_orphan_dataset_items; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_orphan_dataset_items IS 'View containing the tables referenced in dataset but not existing in the database itself.';


--
-- Name: v_orphan_tables; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_orphan_tables AS
 SELECT row_number() OVER () AS id,
    (tables.table_schema)::text AS schemaname,
    (tables.table_name)::text AS tablename
   FROM information_schema.tables
  WHERE ((NOT (concat(tables.table_schema, '.', tables.table_name) IN ( SELECT concat(dataset.schema_name, '.', dataset.table_name) AS concat
           FROM pgmetadata.dataset))) AND ((tables.table_schema)::name <> ALL (ARRAY['pg_catalog'::name, 'information_schema'::name])))
  ORDER BY ((tables.table_schema)::text), ((tables.table_name)::text);


--
-- Name: VIEW v_orphan_tables; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_orphan_tables IS 'View containing the existing tables but not referenced in dataset';


--
-- Name: v_schema_list; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_schema_list AS
 SELECT row_number() OVER () AS id,
    (schemata.schema_name)::text AS schema_name
   FROM information_schema.schemata
  WHERE ((schemata.schema_name)::text <> ALL (ARRAY[('pg_toast'::character varying)::text, ('pg_temp_1'::character varying)::text, ('pg_toast_temp_1'::character varying)::text, ('pg_catalog'::character varying)::text, ('information_schema'::character varying)::text]))
  ORDER BY ((schemata.schema_name)::text);


--
-- Name: VIEW v_schema_list; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_schema_list IS 'View containing list of all schema in this database';


--
-- Name: v_table_comment_from_metadata; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_table_comment_from_metadata AS
 SELECT row_number() OVER () AS id,
    d.schema_name AS table_schema,
    d.table_name,
    concat(d.title, ' - ', d.abstract, ' (', array_to_string(d.categories, ', '::text), ')') AS table_comment,
        CASE
            WHEN ((t.table_type)::text = 'BASE TABLE'::text) THEN 'TABLE'::text
            WHEN ((t.table_type)::text ~~ 'FOREIGN%'::text) THEN 'FOREIGN TABLE'::text
            ELSE (t.table_type)::text
        END AS table_type
   FROM (pgmetadata.dataset d
     LEFT JOIN information_schema.tables t ON (((d.schema_name = (t.table_schema)::text) AND (d.table_name = (t.table_name)::text))));


--
-- Name: VIEW v_table_comment_from_metadata; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_table_comment_from_metadata IS 'View containing the desired formatted comment for the tables listed in the pgmetadata.dataset table. This view is used by the trigger to update the table comment when the dataset item is added or modified';


--
-- Name: v_table_list; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_table_list AS
 SELECT row_number() OVER () AS id,
    (tables.table_schema)::text AS schema_name,
    (tables.table_name)::text AS table_name
   FROM information_schema.tables
  WHERE ((tables.table_schema)::text <> ALL (ARRAY[('pg_toast'::character varying)::text, ('pg_temp_1'::character varying)::text, ('pg_toast_temp_1'::character varying)::text, ('pg_catalog'::character varying)::text, ('information_schema'::character varying)::text]))
  ORDER BY tables.table_schema, ((tables.table_name)::text);


--
-- Name: VIEW v_table_list; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_table_list IS 'View containing list of all tables in this database with schema name';


--
-- Name: v_valid_dataset; Type: VIEW; Schema: pgmetadata; Owner: -
--

CREATE VIEW pgmetadata.v_valid_dataset AS
 SELECT row_number() OVER () AS id,
    d.schema_name,
    d.table_name
   FROM (pgmetadata.dataset d
     LEFT JOIN information_schema.tables t ON (((d.schema_name = (t.table_schema)::text) AND (d.table_name = (t.table_name)::text))))
  WHERE (t.table_name IS NOT NULL)
  ORDER BY d.schema_name, d.table_name;


--
-- Name: VIEW v_valid_dataset; Type: COMMENT; Schema: pgmetadata; Owner: -
--

COMMENT ON VIEW pgmetadata.v_valid_dataset IS 'Gives a list of lines from pgmetadata.dataset with corresponding (existing) tables and views.';


--
-- Name: buildings; Type: TABLE; Schema: pgmetadata_demo; Owner: -
--

CREATE TABLE pgmetadata_demo.buildings (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    full_id character varying,
    osm_id character varying,
    osm_type character varying,
    building character varying,
    name character varying,
    amenity character varying,
    wikipedia character varying,
    height character varying
);


--
-- Name: TABLE buildings; Type: COMMENT; Schema: pgmetadata_demo; Owner: -
--

COMMENT ON TABLE pgmetadata_demo.buildings IS 'Buildings (demo) -  ()';


--
-- Name: Buildings_id_seq; Type: SEQUENCE; Schema: pgmetadata_demo; Owner: -
--

CREATE SEQUENCE pgmetadata_demo."Buildings_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Buildings_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata_demo; Owner: -
--

ALTER SEQUENCE pgmetadata_demo."Buildings_id_seq" OWNED BY pgmetadata_demo.buildings.id;


--
-- Name: footways; Type: TABLE; Schema: pgmetadata_demo; Owner: -
--

CREATE TABLE pgmetadata_demo.footways (
    id integer NOT NULL,
    geom public.geometry(LineString,4326),
    full_id character varying,
    osm_id character varying,
    osm_type character varying,
    highway character varying,
    name character varying,
    bicycle character varying,
    lit character varying,
    surface character varying
);


--
-- Name: TABLE footways; Type: COMMENT; Schema: pgmetadata_demo; Owner: -
--

COMMENT ON TABLE pgmetadata_demo.footways IS 'Footways (demo) -  ()';


--
-- Name: Footways_id_seq; Type: SEQUENCE; Schema: pgmetadata_demo; Owner: -
--

CREATE SEQUENCE pgmetadata_demo."Footways_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Footways_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata_demo; Owner: -
--

ALTER SEQUENCE pgmetadata_demo."Footways_id_seq" OWNED BY pgmetadata_demo.footways.id;


--
-- Name: gardens; Type: TABLE; Schema: pgmetadata_demo; Owner: -
--

CREATE TABLE pgmetadata_demo.gardens (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    full_id character varying,
    osm_id character varying,
    osm_type character varying,
    leisure character varying,
    name character varying,
    landuse character varying,
    wikipedia character varying
);


--
-- Name: TABLE gardens; Type: COMMENT; Schema: pgmetadata_demo; Owner: -
--

COMMENT ON TABLE pgmetadata_demo.gardens IS 'Gardens (demo) - Gardens in the center of Montpellier (BOU, ENV)';


--
-- Name: Gardens_id_seq; Type: SEQUENCE; Schema: pgmetadata_demo; Owner: -
--

CREATE SEQUENCE pgmetadata_demo."Gardens_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Gardens_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata_demo; Owner: -
--

ALTER SEQUENCE pgmetadata_demo."Gardens_id_seq" OWNED BY pgmetadata_demo.gardens.id;


--
-- Name: trees; Type: TABLE; Schema: pgmetadata_demo; Owner: -
--

CREATE TABLE pgmetadata_demo.trees (
    id integer NOT NULL,
    geom public.geometry(Point,4326),
    full_id character varying,
    osm_id character varying,
    osm_type character varying,
    height character varying,
    leaf_type character varying,
    genus character varying
);


--
-- Name: TABLE trees; Type: COMMENT; Schema: pgmetadata_demo; Owner: -
--

COMMENT ON TABLE pgmetadata_demo.trees IS 'Trees (demo) - Trees around the botanical garden in Montpellier.  Source: OpenStreetMap (ENV)';


--
-- Name: Trees_id_seq; Type: SEQUENCE; Schema: pgmetadata_demo; Owner: -
--

CREATE SEQUENCE pgmetadata_demo."Trees_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Trees_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata_demo; Owner: -
--

ALTER SEQUENCE pgmetadata_demo."Trees_id_seq" OWNED BY pgmetadata_demo.trees.id;


--
-- Name: water_surfaces; Type: TABLE; Schema: pgmetadata_demo; Owner: -
--

CREATE TABLE pgmetadata_demo.water_surfaces (
    id integer NOT NULL,
    geom public.geometry(MultiPolygon,4326),
    full_id character varying,
    osm_id character varying,
    osm_type character varying,
    "natural" character varying,
    landuse character varying
);


--
-- Name: TABLE water_surfaces; Type: COMMENT; Schema: pgmetadata_demo; Owner: -
--

COMMENT ON TABLE pgmetadata_demo.water_surfaces IS 'Water Surfaces (demo) -  ()';


--
-- Name: Water_surfaces_id_seq; Type: SEQUENCE; Schema: pgmetadata_demo; Owner: -
--

CREATE SEQUENCE pgmetadata_demo."Water_surfaces_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Water_surfaces_id_seq; Type: SEQUENCE OWNED BY; Schema: pgmetadata_demo; Owner: -
--

ALTER SEQUENCE pgmetadata_demo."Water_surfaces_id_seq" OWNED BY pgmetadata_demo.water_surfaces.id;


--
-- Name: contact id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.contact ALTER COLUMN id SET DEFAULT nextval('pgmetadata.contact_id_seq'::regclass);


--
-- Name: dataset id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset ALTER COLUMN id SET DEFAULT nextval('pgmetadata.dataset_id_seq'::regclass);


--
-- Name: dataset_contact id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset_contact ALTER COLUMN id SET DEFAULT nextval('pgmetadata.dataset_contact_id_seq'::regclass);


--
-- Name: glossary id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.glossary ALTER COLUMN id SET DEFAULT nextval('pgmetadata.glossary_id_seq'::regclass);


--
-- Name: html_template id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.html_template ALTER COLUMN id SET DEFAULT nextval('pgmetadata.html_template_id_seq'::regclass);


--
-- Name: link id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.link ALTER COLUMN id SET DEFAULT nextval('pgmetadata.link_id_seq'::regclass);


--
-- Name: theme id; Type: DEFAULT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.theme ALTER COLUMN id SET DEFAULT nextval('pgmetadata.theme_id_seq'::regclass);


--
-- Name: buildings id; Type: DEFAULT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.buildings ALTER COLUMN id SET DEFAULT nextval('pgmetadata_demo."Buildings_id_seq"'::regclass);


--
-- Name: footways id; Type: DEFAULT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.footways ALTER COLUMN id SET DEFAULT nextval('pgmetadata_demo."Footways_id_seq"'::regclass);


--
-- Name: gardens id; Type: DEFAULT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.gardens ALTER COLUMN id SET DEFAULT nextval('pgmetadata_demo."Gardens_id_seq"'::regclass);


--
-- Name: trees id; Type: DEFAULT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.trees ALTER COLUMN id SET DEFAULT nextval('pgmetadata_demo."Trees_id_seq"'::regclass);


--
-- Name: water_surfaces id; Type: DEFAULT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.water_surfaces ALTER COLUMN id SET DEFAULT nextval('pgmetadata_demo."Water_surfaces_id_seq"'::regclass);


--
-- Data for Name: contact; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.contact (id, name, organisation_name, organisation_unit, email, phone) FROM stdin;
1	Jessie Mosquito	World	GIS	jmosquito@World.com	\N
2	Albert Banana	World	DEV	abanana@World.com	\N
3	Jane Doe	ACME	SIG	jane.doe@acme.corp	\N
\.


--
-- Data for Name: dataset; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.dataset (id, uid, table_name, schema_name, title, abstract, categories, keywords, spatial_level, minimum_optimal_scale, maximum_optimal_scale, publication_date, publication_frequency, license, confidentiality, feature_count, geometry_type, projection_name, projection_authid, spatial_extent, creation_date, update_date, geom, data_last_update, themes) FROM stdin;
5	5c4c3ed3-724d-471e-9904-5dcc25e16edb	water_surfaces	pgmetadata_demo	Water Surfaces (demo)		\N	\N	\N	\N	\N	2021-09-28 08:55:44.606067	\N	\N	\N	6	MULTIPOLYGON	\N	EPSG:4326	3.869998, 3.8721917, 43.6123409, 43.6144272	2021-09-28 08:55:44.606067	2021-09-28 08:55:44.606067	0103000020E610000001000000150000003B5FA230DEF50E4069C0C52F61CE4540EAAEEC82C1F50E409972744B61CE454029CE5147C7F50E4038D4940964CE45401F91A5C5CFF50E40C596790668CE4540072BA96E89F70E40FF678302A5CE45407D6F78E68AF70E4023105432A5CE45405F7EA7C98CF70E40E17CEA58A5CE4540B6D1A52490F70E40226C787AA5CE4540A23A675595F70E40EDE2EC8CA5CE45408DA328869AF70E40EDE2EC8CA5CE454007FE012038F80E40642DF477A5CE4540AB47759549F80E406AD6BE25A5CE454086B652BE56F80E40111B2C9CA4CE45407C61325530FA0E403A85A63682CE454052F6F12B31FA0E405ED1521E82CE4540EDE8C94631FA0E405EA340FA81CE4540BCBD5AA43FFA0E40B75219106BCE454045798B2C3EFA0E4064F899C46ACE45404D767D303AFA0E405E9786866ACE4540C15DAC5E34FA0E40A02AF05F6ACE45403B5FA230DEF50E4069C0C52F61CE4540	\N	\N
6	dabc1c36-d3bb-4c06-afa0-3183ea8f08dc	footways	pgmetadata_demo	Footways (demo)		\N	\N	\N	\N	\N	2021-09-28 08:55:44.606067	\N	\N	\N	71	LINESTRING	\N	EPSG:4326	3.8695894, 3.8744915, 43.6122795, 43.6154941	2021-09-28 08:55:44.606067	2021-09-28 08:55:44.606067	0103000020E6100000010000000F0000004A928C41CCFA0E407041B62C5FCE4540C539EAE8B8FA0E405E32E94A5FCE4540067C235FAEFA0E40FF29B05B5FCE4540534EC5D7E8F60E401DF0AFD469CE45409559CEEF45F50E40B09DDE7B6ECE4540A8B3493437F50E40C108D0A56ECE45400B968F49EBF40E40C181DAB97ACE45408CCDD8E1F9F60E4068E7340BB4CE454083047B0217FA0E40C330BB82C8CE454042CC2555DBFD0E407589343B9CCE4540385AC46636FE0E40367E3C4F97CE4540350A4966F5FE0E404159428875CE4540A9D491C8E3FE0E4020F12BD670CE4540EC6B5D6A84FE0E40D4A70B676DCE45404A928C41CCFA0E407041B62C5FCE4540	\N	\N
7	c834f15d-2938-45e8-a3c4-3489743ce6ab	buildings	pgmetadata_demo	Buildings (demo)		\N	\N	\N	\N	\N	2021-09-28 08:55:44.606067	\N	\N	\N	188	MULTIPOLYGON	\N	EPSG:4326	3.8695065, 3.8752416, 43.6120768, 43.6165715	2021-09-28 08:55:44.606067	2021-09-28 08:55:44.606067	0103000020E6100000010000001600000088388C3853F70E40F651578858CE4540AF3E1EFAEEF60E40F0D69EFE58CE4540409D972FD4F60E4079BAA93759CE454049298D3D20F50E40224212AC60CE4540ECC1A4F8F8F40E40099EE7F461CE4540CB1C812ED0F40E408368AD6873CE45408046E9D2BFF40E406CFF14D8ADCE45402935C52D30F50E4052A92391C7CE45400A9BA67455F50E401F69CB14CECE45408FF51E78C6F80E40FBF14D89DACE454026E1421EC1FD0E40A5129ED0EBCE454075ABE7A4F7FD0E40EECAD35EE9CE4540A63A2EF4D2FE0E402AE0432EDDCE45402ACA00AB7E000F40484B8A3496CE45402ACA00AB7E000F406C97361C96CE4540DDD0949D7E000F4090E3E20396CE4540A56950340F000F4036A6CC727ECE4540A4F2C011EEFF0E40F816D68D77CE4540D053D3E418FF0E407E1EFEF565CE454055826A285AFE0E40AB11B00C60CE45409B5D521097F70E407F07509D58CE454088388C3853F70E40F651578858CE4540	\N	\N
4	e0940d27-0059-4156-85e7-ef6b3cb57230	trees	pgmetadata_demo	Trees (demo)	Trees around the botanical garden in Montpellier.  Source: OpenStreetMap	{ENV}	\N	City	5000	100	2021-09-28 08:55:44.606067	YEA	ODBL	OPE	69	POINT	\N	EPSG:4326	3.8700213, 3.874384, 43.6125281, 43.6155609	2021-09-28 08:55:44.606067	2021-09-28 08:55:44.606067	0103000020E6100000010000000C00000056116E32AAFC0E40C5B01E5267CE454098E3704111F60E40D1FC7B3A68CE4540D34B8C65FAF50E4059E0867368CE4540559632BACDF50E405393E00D69CE454004C6FA0626F70E40A07C30DFB0CE45402397491E99F80E409AAECC00BCCE4540F393C55801F90E405729988CBECE454048C153C895FA0E40D266E613C3CE4540C328AD646CFD0E40211917B3CACE4540522AE109BDFE0E407B50AB43C9CE45407BEC78DD6CFD0E401895D40968CE454056116E32AAFC0E40C5B01E5267CE4540	\N	{ENV}
8	965cdea6-a989-453a-a3ae-a780129791db	gardens	pgmetadata_demo	Gardens (demo)	Gardens in the center of Montpellier	{BOU,ENV}	\N	\N	\N	\N	2021-09-28 08:55:44.606067	NEC	ODBL	OPE	6	MULTIPOLYGON	\N	EPSG:4326	3.8695719, 3.8742129, 43.6121762, 43.6154681	2021-09-28 08:55:44.606067	2021-09-28 08:55:44.606067	0103000020E6100000010000000B000000F01D90DF36FE0E40DD312BCA5BCE4540B9CC446C0BFA0E40A1C096B267CE4540B9BD4978E7F50E40A7C8C62874CE4540272AC01CE2F40E40758EA61F79CE4540542CC8E072F60E40C7736CF3B5CE45404B146B0256F80E409A9DA0A8C7CE45409F19694E03FB0E4070F0E082C7CE454082D6B26B31FE0E40D3A5DA029DCE454038EE395563FE0E409C31715067CE454055826A285AFE0E40AB11B00C60CE4540F01D90DF36FE0E40DD312BCA5BCE4540	\N	{URB}
\.


--
-- Data for Name: dataset_contact; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.dataset_contact (id, fk_id_contact, fk_id_dataset, contact_role) FROM stdin;
4	3	4	OW
5	1	4	DI
\.


--
-- Data for Name: glossary; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.glossary (id, field, code, label_en, description_en, item_order, label_fr, description_fr, label_it, description_it, label_es, description_es, label_de, description_de) FROM stdin;
1	link.mime	octet-stream	application/octet-stream	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
2	link.mime	pdf	application/pdf	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
3	link.mime	xhtml+xml	application/xhtml+xml	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
4	link.mime	json	application/json	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
5	link.mime	xml	application/xml	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
6	link.mime	zip	application/zip	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
7	link.mime	gif	image/gif	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
8	link.mime	jpeg	image/jpeg	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
9	link.mime	png	image/png	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
10	link.mime	tiff	image/tiff	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
11	link.mime	svg+xml	image/svg+xml	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
12	link.mime	csv	text/csv	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
13	link.mime	html	text/html	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
14	link.mime	plain	text/plain	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
16	link.mime	odt	application/vnd.oasis.opendocument.text	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
17	link.mime	ods	application/vnd.oasis.opendocument.spreadsheet	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
18	link.mime	odp	application/vnd.oasis.opendocument.presentation	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
19	link.mime	odg	application/vnd.oasis.opendocument.graphics	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
20	link.mime	xls	application/vnd.ms-excel	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
21	link.mime	xlsx	application/vnd.openxmlformats-officedocument.spreadsheetml.sheet	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
22	link.mime	ppt	application/vnd.ms-powerpoint	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
23	link.mime	pptx	application/vnd.openxmlformats-officedocument.presentationml.presentation	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
24	link.mime	doc	application/msword	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
25	link.mime	docx	application/vnd.openxmlformats-officedocument.wordprocessingml.document	\N	0	\N	\N	\N	\N	\N	\N	\N	\N
26	link.type	OGC:CSW	OGC Catalog Service for the Web	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Catalog service for the web v2.0.2 endpoint (should use different protocol identifier if the endpoint is not v2.0.2; these are not yet defined here).  The gmd:function value in the CI_Online resource should be 'information' if the provided URL is a getCapabilities request. 	\N	\N	\N	\N	\N	\N	\N	\N	\N
27	link.type	OGC:SOS	OGC Sensor Observation Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Sensor Observation service v?? endpoint (should use different protocol identifier if the endpoint is not that version; these are not yet defined here).  The gmd:function value in the CI_Online resource should be 'information' if the provided URL is a getCapabilities request. Note that if the service offers multiple datasets in different offerings, the parameters necessary to access the correct offering should be specified in the gmd:CI_OnlineResource/gmd:description element; recommended practice is to use a JSON object with keys that are parameter names and values that are the necessary parameters.	\N	\N	\N	\N	\N	\N	\N	\N	\N
28	link.type	OGC:SPS	OGC Sensor Planning Service	gmd:protocol value that indicates CI_OnlineResource URL is for an Sensor Planning Service 	\N	\N	\N	\N	\N	\N	\N	\N	\N
29	link.type	OGC:SAS	OGC Sensor Alert Service	gmd:protocol value that indicates CI_OnlineResource URL is for an Sensor Alert Service	\N	\N	\N	\N	\N	\N	\N	\N	\N
30	link.type	OGC:WNS	OGC Web Notification Service	gmd:protocol value that indicates CI_OnlineResource URL is for an Web Notification Service 	\N	\N	\N	\N	\N	\N	\N	\N	\N
31	link.type	OGC:WCS	OGC Web Coverage Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Web coverage service v?? endpoint (should use different protocol identifier if the endpoint is not that version; these are not yet defined here).  The gmd:function value in the CI_Online resource should be 'information' if the provided URL is a getCapabilities request. Note that if the service offers multiple datasets in different coverages, the parameters necessary to access the correct coverage should be specified in the gmd:CI_OnlineResource/gmd:description element; recommended practice is to use a JSON object with keys that are parameter names and values that are the necessary parameters.	\N	\N	\N	\N	\N	\N	\N	\N	\N
32	link.type	OGC:WFS	OGC Web Feature Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Web Feature Service v?? endpoint (should use different protocol identifier if the endpoint is not that version; these are not yet defined here).  The gmd:function value in the CI_Online resource should be 'information' if the provided URL is a getCapabilities request. Note that if the service offers multiple datasets in different feature types the typeName parameter necessary to access the correct data should be specified in the gmd:CI_OnlineResource/gmd:description element; recommended practice is to use a JSON object with keys that are parameter names and values that are the necessary parameters.	\N	\N	\N	\N	\N	\N	\N	\N	\N
33	link.type	OGC:WMS	OGC Web Map Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Web Map Service v?? endpoint (should use different protocol identifier if the endpoint is not that version; these are not yet defined here).  The gmd:function value in the CI_Online resource should be 'information' if the provided URL is a getCapabilities request. Note that if the service offers multiple datasets in different map layers, the layers parameters necessary to access the correct data should be specified in the gmd:CI_OnlineResource/gmd:description element; recommended practice is to use a JSON object with keys that are parameter names and values that are the necessary parameters.	\N	\N	\N	\N	\N	\N	\N	\N	\N
34	link.type	OGC:WMS-C	OGC Web Map Service - Cached	This is an unofficial profile of WMS using OSGeo recommendations to pull cached map tiles from the server when available. Often this is specified with a 'tiled=true' URL parameter in the GetMap request.	\N	\N	\N	\N	\N	\N	\N	\N	\N
35	link.type	OGC:WMTS	OGC Web Map Tile Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Web Map Tile Service	\N	\N	\N	\N	\N	\N	\N	\N	\N
36	link.type	OGC:WPS	OGC Web Processing Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Web Processing Service v?? endpoint (should use different protocol identifier if the endpoint is not that version; these are not yet defined here).  The gmd:function value in the CI_Online resource should be 'information' if the provided URL is a getCapabilities request. Other parameters necessary to access the correct processing service should be specified in the gmd:CI_OnlineResource/gmd:description element; recommended practice is to use a JSON object with keys that are parameter names and values that are the necessary parameters.	\N	\N	\N	\N	\N	\N	\N	\N	\N
37	link.type	OGC:ODS	OGC OpenLS Directory Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC OpenLS Directory Service 	\N	\N	\N	\N	\N	\N	\N	\N	\N
38	link.type	OGC:OGS	OGC OpenLS Gateway Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC OpenLS Gateway Service	\N	\N	\N	\N	\N	\N	\N	\N	\N
39	link.type	OGC:OUS	OGC OpenLS Utility Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC OpenLS Utility Service	\N	\N	\N	\N	\N	\N	\N	\N	\N
40	link.type	OGC:OPS	OGC OpenLS Presentation Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC OpenLS Presentation Service 	\N	\N	\N	\N	\N	\N	\N	\N	\N
41	link.type	OGC:ORS	OGC OpenLS Route Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC OpenLS Route Service	\N	\N	\N	\N	\N	\N	\N	\N	\N
42	link.type	OGC:CT	OGC Coordinate Transformation Service	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Coordinate Transformation Service	\N	\N	\N	\N	\N	\N	\N	\N	\N
43	link.type	OGC:WFS-G	Gazetteer Service Profile of the Web Feature Service Implementation Specification	gmd:protocol value that indicates CI_OnlineResource URL is for an OGC Gazetteer Service Profile of the Web Feature Service Implementation Specification	\N	\N	\N	\N	\N	\N	\N	\N	\N
44	link.type	OGC:OWC	OGC OWS Context	Specifies a fully configured service set which can be exchanged	\N	\N	\N	\N	\N	\N	\N	\N	\N
46	link.type	OGC:IoT	OGC SensorThings API	gmd:protocol value that indicates CI_OnlineResource URL is for a SensorThings API	\N	\N	\N	\N	\N	\N	\N	\N	\N
47	link.type	ESRI:ArcIMS	ESRI ArcIMS Service	gmd:protocol value that indicates CI_OnlineResource URL is for an ArcIMS endpoint. ArcIMS requests are tunneled via HTTP Get URL's	\N	\N	\N	\N	\N	\N	\N	\N	\N
48	link.type	ESRI:ArcGIS	ESRI ArcGIS Service	gmd:protocol value that indicates CI_OnlineResource URL is for an ESRI Map service endpoint. ESRI REST requests are tunneled via HTTP Get URL's	\N	\N	\N	\N	\N	\N	\N	\N	\N
50	link.type	OPeNDAP:OPeNDAP	OPeNDAP root URL	Link is the root URL for an OpenDAP endpoint. An OPeNDAP server replies to queries for data and other services in the form of specially formed URLs that start with a root URL, and use a suffix on the root URL and a constraint expression to indicate which service is requested and what the parameters are. Example suffixes are dods, das, dds, nc. OpenDAP defines a syntax for constraint expressions as well.	\N	\N	\N	\N	\N	\N	\N	\N	\N
51	link.type	OPeNDAP:Hyrax	OPeNDAP Hyrax server	Link is the root URL for an This is the OPeNDAP 4 Data Server, also known as Hyrax. Hyrax is a data server that implements the DAP2 and DAP4 protocols, works with a number of different data formats and supports a wide variety of customization options from tailoring the look of the server's web pages to complex server-side processing operations.	\N	\N	\N	\N	\N	\N	\N	\N	\N
52	link.type	UNIDATA:NCSS	NetCDF Subset Service	Link is the root URL for a THREDDS datasets. The NetCDF Subset Service enables subsetting CDM scientific datasets using earth coordinates, such as lat/lon bounding boxes and date ranges; requests are made via HTTP GET with key-value pairs (KVP) for parameters encoded in HTTP URIs.  The resources identified are THREDDS datasets. The resource URIs have a root host name and path, typically something like http://servername:8080/thredds/ncss/, followed by a path that identifies a particular dataset {path/dataset}. A subset of the dataset is considered a view of a resource, specified by query parameters following the character '?' after the dataset path: http://servername:8080/thredds/ncss/{path/dataset}?{subset}. An 'accept' parameter may be used to specify the desired resource representation.	\N	\N	\N	\N	\N	\N	\N	\N	\N
53	link.type	UNIDATA:CDM	Common Data Model Remote Web Service	Example	\N	\N	\N	\N	\N	\N	\N	\N	\N
54	link.type	UNIDATA:CdmRemote	Common Data Model index subsetting	CDM Remote provides remote access to UNIDATA Common Data Model (CDM) datasets, using ncstream as the on-the-wire protocol. Client requests are of the form endpoint?query, and the specification defines a vocabulary of valid query parameters. There are two levels of service: 1) CdmRemote provides index subsetting on remote CDM datasets; 2) CdmrFeature provides coordinate subsetting on remote CDM Feature Datasets	\N	\N	\N	\N	\N	\N	\N	\N	\N
55	link.type	UNIDATA:CdmrFeature	Common Data Model coordinate subsetting	Link is endpoint URL that provides coordinate subsetting on UNIDATA Common Data Model (CDM) datasets, using ncstream as the on-the-wire protocol. Client requests are of the form endpoint?query, and the specification defines a vocabulary of valid query parameters.	\N	\N	\N	\N	\N	\N	\N	\N	\N
56	link.type	UNIDATA:THREDDS	THREDDS Catalog	Link is a THREDDS Catalog URL that provides the XML for traversing programmatically. Can be used for datasets and collections of datasets.	\N	\N	\N	\N	\N	\N	\N	\N	\N
57	link.type	OGC:GML	OGC Geography Markup Language	Example	\N	\N	\N	\N	\N	\N	\N	\N	\N
59	link.type	WWW:WSDL	Web Service Description Language XML document describing service operation		\N	\N	\N	\N	\N	\N	\N	\N	\N
60	link.type	WWW:SPARQL:1.1	SPARQL protocol for HTTP	SPARQL Protocol specifies a means for conveying SPARQL queries and updates to a SPARQL processing service and returning the results via HTTP to the entity that requested them	\N	\N	\N	\N	\N	\N	\N	\N	\N
61	link.type	OpenSearch1.1	OpenSearch template	use to indicate link is a template conforming to the OpenSearch specification	\N	\N	\N	\N	\N	\N	\N	\N	\N
62	link.type	OpenSearch1.1:Description	OpenSearch description document	indicates a link to get an openSearch description document	\N	\N	\N	\N	\N	\N	\N	\N	\N
64	link.type	template	link provides template to access resource	Link text is a URI template; applicationProfile attribute value associated with the link should indicate the specification for the template scheme (e.g. OpenSearch1.1).	\N	\N	\N	\N	\N	\N	\N	\N	\N
69	link.type	esip:CollectionCast	ESIP collection cast		\N	\N	\N	\N	\N	\N	\N	\N	\N
70	link.type	tilejson:2.0.0	tile mill map service description	link is description of a TileMill map service endpoint. Link type would be application/json; function would be information.	\N	\N	\N	\N	\N	\N	\N	\N	\N
71	link.type	iris:fdsnws-event	IRIS Seismic event service	Link returns event (earthquake) information from the catalogs submitted to the IRIS DMC	\N	\N	\N	\N	\N	\N	\N	\N	\N
72	link.type	QuakeML1.2	Earthquake markup language	XML markup language for earthquake hypocenter data	\N	\N	\N	\N	\N	\N	\N	\N	\N
75	link.type	ISO-USGIN	USGIN-profile ISO 19115 metadata	This is the CharacterString Value mandated by the USGIN profile of ISO19115/19139 for instance documents to self-identify.  	\N	\N	\N	\N	\N	\N	\N	\N	\N
76	link.type	http	Hypertext transfer Protocol, v1.1	Use to indicate gmd:CI_OnlineResource URLs that are simple http links to a target resource representation for download; redundant as the URL prefix 'http:' conveys the same information.	\N	\N	\N	\N	\N	\N	\N	\N	\N
77	link.type	https	HTTP over TLS	Use to indicate gmd:CI_OnlineResource URLs that are simple https links to a target resource representation for download; redundant as the URL prefix 'https:' conveys the same information.	\N	\N	\N	\N	\N	\N	\N	\N	\N
78	link.type	ftp	FILE TRANSFER PROTOCOL (FTP)	Use to indicate gmd:CI_OnlineResource URLs that are simple ftp links to a target resource representation for download; redundant as the URL prefix 'ftp:' conveys the same information.	\N	\N	\N	\N	\N	\N	\N	\N	\N
79	link.type	IETF:GeoJSON	GeoJSON	GeoJSON is a geospatial data interchange format based on JavaScript Object Notation (JSON)	\N	\N	\N	\N	\N	\N	\N	\N	\N
80	link.type	GIT	GIT	gmd:protocol value that indicates CI_OnlineResource URL is for a GIT repository	\N	\N	\N	\N	\N	\N	\N	\N	\N
81	link.type	OKFN:datapackage	OKFN Data Package	A Data Package is a simple way of packaging up data	\N	\N	\N	\N	\N	\N	\N	\N	\N
82	link.type	boundless:geogig	Boundless GeoGig	gmd:protocol value that indicates CI_OnlineResource URL is for a GeoGig REST API	\N	\N	\N	\N	\N	\N	\N	\N	\N
83	link.type	OASIS:OData:4.0	OData v4.0	gmd:protocol value that indicates CI_OnlineResource URL is for an OData JSON endpoint	\N	\N	\N	\N	\N	\N	\N	\N	\N
84	link.type	maxogden:dat	dat REST API	gmd:protocol value that indicates CI_OnlineResource URL is for a dat REST API	\N	\N	\N	\N	\N	\N	\N	\N	\N
85	link.type	geoserver:rest	GeoServer REST configuration API	gmd:protocol value that indicates CI_OnlineResource URL is for a Geoserver rest API to configure featuretypes in Geoserver (and mapserver) remotely	\N	\N	\N	\N	\N	\N	\N	\N	\N
86	link.type	google:protocol-buffers	Google Protocol Buffers	Googles mechanism for serializing structured data	\N	\N	\N	\N	\N	\N	\N	\N	\N
87	link.type	google:fusion-tables	Google Fusion Tables	Google mechanism for interacting with online data tables	\N	\N	\N	\N	\N	\N	\N	\N	\N
88	link.type	NOAA:LAS	Live Access Server	gmd:protocol value that indicates CI_OnlineResource URL is a LAS endpoint	\N	\N	\N	\N	\N	\N	\N	\N	\N
90	link.type	ERDDAP:griddap	ERDDAP Data Service for Gridded Datasets	griddap lets you request a data subset, graph, or map from a gridded dataset (for example, sea surface temperature data from a satellite), via a specially formed URL. griddap uses the OPeNDAP (external link) Data Access Protocol (DAP) (external link) and its projection constraints (external link).  Link is the root URL for an ERDDAP griddap service endpoint. The service responds to OPeNDAP requests and related ERDDAP-specific requests to a gridded dataset. A request starts with this root URL, adds a file type extension, and sometimes a constraint expression to specify a subset of data. Example file type extensions which don't require a constraint are .das, .dds, .html, and .graph. Example file type extensions which do require a constraint are .dods, .nc, .mat, .json, and .htmlTable. Full documentation for ERDDAP API at http://coastwatch.pfeg.noaa.gov/erddap/rest.html	\N	\N	\N	\N	\N	\N	\N	\N	\N
91	link.type	ERDDAP:tabledap	ERDDAP Data Service for Tabular Datasets	Tabledap lets you request a data subset, a graph, or a map from a tabular dataset (for example, buoy data), via a specially formed URL. tabledap uses the OPeNDAP (external link) Data Access Protocol (DAP) (external link) and its selection constraints (external link).  Link is the root URL for an ERDDAP tabledap service endpoint. The service responds to OPeNDAP requests and related ERDDAP-specific requests to a tabular (sequence) dataset. A request starts with this root URL, adds a file type extension, and sometimes a constraint expression to specify a subset of data. Example file type extensions which don't require a constraint are .das, .dds, .html, and .graph. Example file type extensions which do require a constraint are .dods, .nc, .mat, .json, and .htmlTable.  Full documentation for ERDDAP API at http://coastwatch.pfeg.noaa.gov/erddap/rest.html	\N	\N	\N	\N	\N	\N	\N	\N	\N
92	link.type	OASIS:AMQP	Advanced Message Queuing Protocol	gmd:protocol value that indicates CI_OnlineResource URL is for an AMQP broker	0	\N	\N	\N	\N	\N	\N	\N	\N
15	link.mime	txml	text/xml	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
128	dataset.license	LO-2.0	Licence Ouverte Version 2.0	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
129	dataset.license	LO-2.1	Licence Ouverte Version 2.1	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
45	link.type	OGC:GPKG	OGC Geopackage	SQLite Extension for exchange or direct use of vector geospatial features and / or tile matrix sets of earth images and raster maps at various scales	\N	\N	\N	\N	\N	\N	\N	OGC Geopackage	SQLite-Erweiterung für den Austausch und direkte Verwendung von räumlichen Vektor-Geodaten und/oder Kachel-Matrizen von Bildern und Rasterkarten in unterschiedlichen Maßstäben
49	link.type	ESRI:MPK	ArcGIS Map Package	Example URI for ArcGIS Map Package. Mpk is a file format. A map package contains a map document (.mxd) and the data referenced by the layers it contains, packaged into one convenient, portable file.	\N	\N	\N	\N	\N	\N	\N	ArcGIS Map Package	URI eines ArcGIS Map Packages. MPK ist ein Dateiformat, das ein Kartendokument (.mxd) und die von den Layern genutzten Daten in einer einfach austauschbaren Datei enthält
58	link.type	WWW:LINK	Web Address (URL)	Indicates that XLINK properties are encoded as key-value pairs in content of a dct:references element to provide a machine actionable link. 	\N	\N	\N	\N	\N	\N	\N	Web-Adresse (URL)	Zeigt an, dass XLINK-Eigenschaften als Schlüssel-Wert-Paare im Inhalt eines dct:references-Elements enhalten sind, um einen maschinell auswertbaren Link bereitzustellen.
63	link.type	information	link provides information about resource	function of link it to http:GET information about resource	\N	\N	\N	\N	\N	\N	\N	Link liefert Informationen über die Ressource	Link für http:GET von Informationen über die Ressource
65	link.type	download	link will get resource	function of link it to http:GET a representation of the resource; the link type attribute value(s) should indicate the MIME types of available representations	\N	\N	\N	\N	\N	\N	\N	Link lädt die Ressource	Link für http:GET einer Repräsentation der Ressource; das/die Link-Typ-Attribut(e) sollten die MIME-Typen der verfügbaren Repräsentationen angeben
66	link.type	service	link is service endpoint	Link value is the URL of a service endpoint; the link protocol and applicationProfile (and possibly other link properties like overlayAPI, depending on the link attributes profile in use) attribute values should identify the service protocol specification	\N	\N	\N	\N	\N	\N	\N	Link ist Service-Endpunkt	Der Link ist der URL eines Service-Endpunkts; das Link-Protokoll und applicationProfile-Attributwert (und möglicherweise weitere Linkeigenschaften wie overlayAPI, abhängig vom verwendeten Link-Attribut-Profil) sollten die Service-Protokollspezifikation identifizieren
67	link.type	order	link provides form to obtain resource	link value is URL of web application requiring user interaction to order/request access to the resource	\N	\N	\N	\N	\N	\N	\N	Link stellt Formular zum Erwerb der Ressource zur Verfügung	Linkziel ist der URL einer Webanwendung, die Benutzerinteraktion zum Erwerb der bzw. Anfrage zur Bereitstellung der Ressource erfordert
68	link.type	search	link provides form for searching resource	link value is URL of web application requiring user interaction to search/browse/subset the resource.	\N	\N	\N	\N	\N	\N	\N	Link stellt Formular zur Suche der Ressource zur Verfügung	Linkziel ist der URL einer Webanwendung, die Benutzerinteraktion zum Suchen/Auswählen der Resoource erfordert
73	link.type	file	a file	CKAN metadata vocabulary for populating the type attribute on a CKAN resource; indicates that an http  GET of this url should yield a bitstream	\N	\N	\N	\N	\N	\N	\N	eine Datei	CKAN Metadata Vocabulary, um die Typattribute einer CKAN-Ressource zu füllen; zeigt an, dass ein http:GET dieses URL einen Bitstream liefern sollte
74	link.type	ISO 19115:2003/19139	ISO 19115 metadata in ISO19139 encoding	This is the CharacterString value used by Geonetwork OpenSource to identify ISO metadata record instances; apparently have to assume that its using the 2006 corrigendum with no specific profile conventions.	\N	\N	\N	\N	\N	\N	\N	ISO19115-Metadaten in ISO19139-Kodierung	Dies ist der CharacterString, der von Geonetwork OpenSource genutzt wird, um ISO-Metadateneintragsinstanzen zu identifizieren; offensichtlich ist anzunehmen, dass es das Korrigendum von 2006 ohne spezifische Profil-Konventionen nutzt.
89	link.type	OSM	Open Street Map API	gmd:protocol value that indicates CI_OnlineResource URL is for a OSM APIfor fetching and saving raw geodata from/to an OpenStreetMap database 	\N	\N	\N	\N	\N	\N	\N	OpenStreetMap-Schnittstelle	gmd:protocol-Wert, der anzeigt, dass die CI_OnlineResource-URL für eine OSM-API zum Holen und Speichern von Roh-Geodaten von/zu einer OpenStreetMap-Datenbank ist
96	dataset.license	CC0	Creative Commons CC Zero	\N	10	\N	\N	\N	\N	\N	\N	Creative Commons Zero	\N
97	dataset.license	CC-BY-4.0	Creative Commons Attribution 4.0	\N	20	\N	\N	\N	\N	\N	\N	Creative Commons Namensnennung – Version 4.0	\N
98	dataset.license	CC-BY-SA-4.0	Creative Commons Attribution Share-Alike 4.0	\N	30	\N	\N	\N	\N	\N	\N	Creative Commons  Namensnennung – Weitergabe unter gleichen Bedingungen – Version 4.0	\N
99	dataset.license	ODC-BY	Open Data Commons Attribution License	\N	40	\N	\N	\N	\N	\N	\N	Open Data Commons Namensnennung	\N
100	dataset.license	ODBL	Open Data Commons Open Database License	\N	50	\N	\N	\N	\N	\N	\N	Open Data Commons Lizenz für Datenbankinhalte	\N
101	dataset.license	PDDL	Open Data Commons Public Domain Dedication and Licence	\N	60	\N	\N	\N	\N	\N	\N	Open Data Commons Gemeinfreiheit-Widmung und Lizenz	\N
93	contact.contact_role	CU	Custodian	\N	10	Dépositaire	\N	\N	\N	\N	\N	Verwalter	Person oder Stelle, welche die Zuständigkeit und Verantwortlichkeit für einen Datensatz übernommen hat und seine sachgerechte Pflege und Wartung sichert
94	contact.contact_role	DI	Distributor	\N	20	Distributeur	\N	\N	\N	\N	\N	Vertrieb	Person oder Stelle für den Vertrieb
95	contact.contact_role	OW	Owner	\N	30	Propriétaire	\N	\N	\N	\N	\N	Eigentümer	Eigentümer der Ressource
113	dataset.categories	HEA	Health	\N	\N	Santé	\N	\N	\N	\N	\N	Gesundheitswesen 	Gesundheit, Gesundheitsdienste, Humanökologie und Betriebssicherheit
112	dataset.categories	ELE	Elevation	\N	\N	Altitude	\N	\N	\N	\N	\N	Höhenangaben	Höhenangabe bezogen auf ein Höhenreferenzsystem
111	dataset.categories	GEO	Geoscientific Information	\N	\N	Informations géoscientifiques	\N	\N	\N	\N	\N	Geowissenschaften	geowissenschaftliche Informationen
110	dataset.categories	PLA	Planning Cadastre	\N	\N	Planification/Cadastre	\N	\N	\N	\N	\N	Planungsunterlagen, Kataster	Informationen für die Flächennutzungsplanung
109	dataset.categories	INL	Inland Waters	\N	\N	Eaux intérieures	\N	\N	\N	\N	\N	Binnengewässer	Binnengewässerdaten, Gewässernetze und deren Eigenschaften
108	dataset.categories	BOU	Boundaries	\N	\N	Limites	\N	\N	\N	\N	\N	Grenzen	gesetzlich festgelegte Grenzen
107	dataset.categories	STR	Structure	\N	\N	Structure	\N	\N	\N	\N	\N	Bauwerke	anthropogene Bauten
106	dataset.categories	TRA	Transportation	\N	\N	Transport	\N	\N	\N	\N	\N	Verkehrswesen	Mittel und Wege zur Beförderung von Personen und/oder Gütern
105	dataset.categories	INT	Intelligence Military	\N	\N	Renseignement/Secteur militaire	\N	\N	\N	\N	\N	Militär und Aufklärung	Militärbasen, militärische Einrichtungen und Aktivitäten
104	dataset.categories	LOC	Location	\N	\N	Localisation	\N	\N	\N	\N	\N	Ortsangaben	Positionierungsangaben und -dienste
103	dataset.categories	CLI	Climatology Meteorology Atmosphere	\N	\N	Climatologie/Météorologie/Atmosphère	\N	\N	\N	\N	\N	Atmosphäre	Prozesse und Naturereignisse der Atmosphäre inkl. Klimatologie und Meteorologie
102	dataset.categories	FAR	Farming	\N	\N	Agriculture	\N	\N	\N	\N	\N	Landwirtschaft	Tierzucht und/oder Pflanzenanbau
116	dataset.categories	ENV	Environment	\N	\N	Environnement	\N	\N	\N	\N	\N	Umwelt	Umweltressourcen, Umweltschutz und Umwelterhaltung
115	dataset.categories	OCE	Oceans	\N	\N	Océans	\N	\N	\N	\N	\N	Meere	Merkmale und Charakteristika von salzhaltigen  Gewässern (außer Binnengewässern)
114	dataset.categories	BIO	Biota	\N	\N	Biote	\N	\N	\N	\N	\N	Biologie	Flora und/oder Fauna in der natürlichen Umgebung
120	dataset.categories	IMA	Imagery Base Maps Earth Cover	\N	\N	Imagerie/Cartes de base/Occupation des terres	\N	\N	\N	\N	\N	Oberflächenbeschreibung	Basiskarten und -daten
119	dataset.categories	SOC	Society	\N	\N	Société	\N	\N	\N	\N	\N	Gesellschaft	kulturelle und gesellschaftliche Merkmale
118	dataset.categories	ECO	Economy	\N	\N	Économie	\N	\N	\N	\N	\N	Wirtschaft	wirtschaftliche Aktivitäten, Verhältnisse und Beschäftigung
117	dataset.categories	UTI	Utilities Communication	\N	\N	Services d’utilité publique/Communication	\N	\N	\N	\N	\N	Ver- und Entsorgung, Kommunikation	Energie-, Wasser- und Abfallsysteme, Kommunikationsinfrastruktur und -dienste
121	dataset.confidentiality	OPE	Open	No restriction access for this dataset	1	Ouvert	Aucune restriction d'accès pour ce jeu de données	\N	\N	\N	\N	offen	Keine Einschränkungen des Zugriffs auf diese Daten
122	dataset.confidentiality	RES	Restricted	The dataset access is restricted to some users	2	Restreint	L'accès au jeu de données est restreint à certains utilisateurs	\N	\N	\N	\N	eingeschränkt	Der Zugriff auf die Daten ist auf ausgewählte Nutzer beschränkt
124	dataset.publication_frequency	YEA	Yearly	Update data yearly	2	Annuel	Mise à jour annuelle	\N	\N	\N	\N	jährlich	Daten werden jährlich aktualisiert
123	dataset.publication_frequency	NEC	When necessary	Update data when necessary	1	Lorsque nécessaire	Mise à jour lorsque nécessaire	\N	\N	\N	\N	bei Bedarf	Daten werden bei Bedarf aktualisiert
130	dataset.license	dl-de/by-2-0	Data licence Germany – attribution – version 2.0	\N	80	\N	\N	\N	\N	\N	\N	Datenlizenz Deutschland – Namensnennung – Version 2.0	\N
131	dataset.license	proj	Restricted use for project-related work	\N	90	\N	\N	\N	\N	\N	\N	nur für Projektbearbeitung	\N
132	dataset.publication_frequency	BIA	Biannually	Update data twice each year	3	\N	\N	\N	\N	\N	\N	halbjährlich	Daten werden halbjährlich aktualisiert
133	dataset.publication_frequency	IRR	Irregular	Data is updated in intervals that are uneven in duration	7	\N	\N	\N	\N	\N	\N	unregelmäßig	Daten werden unregelmäßig aktualisiert
134	dataset.publication_frequency	NOP	Not planned	There are no plans to update the data	8	\N	\N	\N	\N	\N	\N	nicht geplant	eine Aktualisierung der Daten ist nicht geplant
135	contact.contact_role	OR	Originator	Party who created the resource	40	\N	\N	\N	\N	\N	\N	Urheber	Erzeuger der Ressource
136	contact.contact_role	PR	Processor	Party who has processed the data in a manner such that the resource has been modified	50	\N	\N	\N	\N	\N	\N	Bearbeiter	Person oder Stelle, die die Ressource in einem Arbeitsschritt verändert hat
127	dataset.publication_frequency	DAY	Daily	Update data daily	6	Journalier	Mise à jour journalière	\N	\N	\N	\N	täglich	Daten werden täglich aktualisiert
125	dataset.publication_frequency	MON	Monthly	Update data monthly	4	Mensuel	Mise à jour mensuelle	\N	\N	\N	\N	monatlich	Daten werden monatlich aktualisiert
126	dataset.publication_frequency	WEE	Weekly	Update data weekly	5	Hebdomadaire	Mise à jour hebdomadaire	\N	\N	\N	\N	wöchentlich	Daten werden wöchentlich aktualisiert
\.


--
-- Data for Name: html_template; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.html_template (id, section, content) FROM stdin;
1	contact	<tr>\n    <td>[% contact_role %]</td>\n    <td>[% name %]</td>\n    <td>[% organisation_name %] ([% organisation_unit %])</td>\n    <td>[% email %]</td>\n</tr>\n
2	link	<tr>\n    <td><span title="[% type_label %]">[% type %]</span></td>\n    <td><a title="[% description %]" href="[% url %]" target="_blank">[% name %]</a></td>\n    <td><span title="[% mime_label %]">[% mime %]</span></td>\n    <td>[% format %]</td>\n    <td>[% size %]</td>\n</tr>\n
3	main	<div>\n    <h3>Identification</h3>\n    <table class="table table-condensed">\n        <tr>\n            <th>Title</th><td>[% title %]</td>\n        </tr>\n        <tr>\n            <th>Abstract</th><td>[% abstract %]</td>\n        </tr>\n        <tr>\n            <th>Categories</th><td>[% categories %]</td>\n        </tr>\n        <tr>\n            <th>Themes</th><td>[% themes %]</td>\n        </tr>\n        <tr>\n            <th>Keywords</th><td>[% keywords %]</td>\n        </tr>\n        <tr>\n            <th>Data last update</th><td>[% data_last_update %]</td>\n        </tr>\n    </table>\n</div>\n\n<div>\n    <h3>Spatial properties</h3>\n    <table class="table table-condensed">\n        <tr>\n            <th>Level</th><td>[% spatial_level %]</td>\n        </tr>\n        <tr>\n            <th>Minimum scale</th><td>[% minimum_optimal_scale %]</td>\n        </tr>\n        <tr>\n            <th>Maximum scale</th><td>[% maximum_optimal_scale %]</td>\n        </tr>\n        <tr>\n            <th>Feature count</th><td>[% feature_count %]</td>\n        </tr>\n        <tr>\n            <th>Geometry</th><td>[% geometry_type %]</td>\n        </tr>\n        <tr>\n            <th>Extent</th><td>[% spatial_extent %]</td>\n        </tr>\n        <tr>\n            <th>Projection name</th><td>[% projection_name %]</td>\n        </tr>\n        <tr>\n            <th>Projection ID</th><td>[% projection_authid %]</td>\n        </tr>\n    </table>\n</div>\n\n<div>\n    <h3>Publication</h3>\n    <table class="table table-condensed">\n        <tr>\n            <th>Date</th><td>[% publication_date %]</td>\n        </tr>\n        <tr>\n            <th>Frequency</th><td>[% publication_frequency %]</td>\n        </tr>\n        <tr>\n            <th>License</th><td>[% license %]</td>\n        </tr>\n        <tr>\n            <th>Confidentiality</th><td>[% confidentiality %]</td>\n        </tr>\n    </table>\n</div>\n\n<div>\n    <h3>Links</h3>\n    <table class="table table-condensed table-striped table-bordered">\n        <tr>\n            <th>Type</th>\n            <th>Name</th>\n            <th>MIME</th>\n            <th>Format</th>\n            <th>Size</th>\n        </tr>\n        [% meta_links %]\n    </table>\n</div>\n\n<div>\n    <h3>Contacts</h3>\n    <table class="table table-condensed table-striped table-bordered">\n        <tr>\n            <th>Role</th>\n            <th>Name</th>\n            <th>Organisation</th>\n            <th>Email</th>\n        </tr>\n        [% meta_contacts %]\n    </table>\n</div>\n\n<div>\n    <h3>Metadata</h3>\n    <table class="table table-condensed">\n        <tr>\n            <th>Table</th><td>[% table_name %]</td>\n        </tr>\n        <tr>\n            <th>Schema</th><td>[% schema_name %]</td>\n        </tr>\n        <tr>\n            <th>Creation</th><td>[% creation_date %]</td>\n        </tr>\n        <tr>\n            <th>Update</th><td>[% update_date %]</td>\n        </tr>\n        <tr>\n            <th>UUID</th><td>[% uid %]</td>\n        </tr>\n    </table>\n</div>\n
\.


--
-- Data for Name: link; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.link (id, name, type, url, description, format, mime, size, fk_id_dataset) FROM stdin;
2	OSM OverPass Turbo data access	WWW:LINK	https://overpass-turbo.eu/s/1bzv	Service WFS pour récupérer les données	\N	html	\N	4
1	Web page with description	WWW:LINK	https://docs.3liz.org/qgis-pgmetadata-plugin/	Web page containing details about this dataset	\N	html	\N	4
\.


--
-- Data for Name: qgis_plugin; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.qgis_plugin (id, version, version_date, status) FROM stdin;
0	1.2.0	2022-09-19	1
\.


--
-- Data for Name: theme; Type: TABLE DATA; Schema: pgmetadata; Owner: -
--

COPY pgmetadata.theme (id, code, label, description) FROM stdin;
1	ENV	Environnement et Climat	\N
2	URB	Aménagement et Urbanisme	\N
3	REF	Limites administratives et référentiels	\N
\.


--
-- Data for Name: buildings; Type: TABLE DATA; Schema: pgmetadata_demo; Owner: -
--

COPY pgmetadata_demo.buildings (id, geom, full_id, osm_id, osm_type, building, name, amenity, wikipedia, height) FROM stdin;
1	0106000020E61000000100000001030000000200000006000000AA46AF0628FD0E408B1C7D27C1CE45400BF148BC3CFD0E40A76B370BC5CE4540F69BE4A2B5FD0E40DD0E6844C4CE4540B97F76D1A1FD0E40973AC8EBC1CE4540DE1099A894FD0E400381295EC0CE4540AA46AF0628FD0E408B1C7D27C1CE4540060000002B5CA0EE4DFD0E408B5EFC23C2CE4540E8D9ACFA5CFD0E4026F5AFF6C1CE454092C3712A63FD0E40A3CEDC43C2CE45401382B0AE65FD0E4019FF3EE3C2CE4540235FAEEA51FD0E40FBE59315C3CE45402B5CA0EE4DFD0E408B5EFC23C2CE4540	r1226885	1226885	relation	yes	\N	\N	\N	\N
2	0106000020E61000000100000001030000000200000019000000526CBBBF30FF0E40615DCB1AABCE4540C993A46B26FF0E406790CC34ABCE4540C993A46B26FF0E40C6C61748ABCE45401C107C670FFF0E401F268689ABCE4540D79F692EDCFE0E40BAD0A634ACCE4540B6FA4564B3FE0E4025F72AE8ACCE4540C5F13279B9FE0E40A7BBA1DFADCE454021E28B9BBFFE0E40E8BE9CD9AECE454043A78C24E6FE0E4095360B6AAECE454022CDB3ED0FFF0E40E3772EE7ADCE4540E04DB7EC10FF0E40A1E4C40DAECE4540918B208436FF0E40669E019AADCE4540EC5B9CE73EFF0E40A6875748AFCE4540FC7266BB42FF0E40D60BF43FAFCE45407414D67C4BFF0E4077D5A82CAFCE454051A3906456FF0E402FE12B15AFCE454099DFC4EB55FF0E40532DD8FCAECE4540C12A285657FF0E40532DD8FCAECE4540385211024DFF0E40D759E322ADCE45403398D06E3EFF0E405A0AED41ADCE454083D1F6F939FF0E408A4C0A3DACCE4540A67C08AA46FF0E408A1EF818ACCE4540E33ECD2445FF0E400740DCD5ABCE4540C7AD934440FF0E40FCF37EEDAACE4540526CBBBF30FF0E40615DCB1AABCE45400700000014F6A39707FF0E40DD787764ACCE4540CBB6781D16FF0E409051F932ACCE4540BDFC4E9319FF0E40EF3F8DD6ACCE45406B6688BE16FF0E40E93A9EE0ACCE454029E78BBD17FF0E4024253D0CADCE454077C311FF0BFF0E400D118134ADCE454014F6A39707FF0E40DD787764ACCE4540	r1226886	1226886	relation	yes	\N	\N	\N	\N
3	0106000020E610000001000000010300000002000000140000002B22799DC3FB0E4032E94A5F63CE45404A134ABAC1FB0E40A961646E63CE45406EC1525DC0FB0E40CD09359E63CE4540BBBABE6AC0FB0E40A9BD88B663CE45409DC9ED4DC2FB0E40C7606AF063CE454027FCADF8E1FB0E403DB9A64066CE4540ADAEF9A70AFC0E40974C5F1965CE4540FCE4284014FC0E4073B8FBC165CE4540AA4E626B11FC0E404F6C4FDA65CE45407F1DEED929FC0E40CB11329067CE4540D770EC342DFC0E404EF04DD367CE4540CC1363F437FC0E40BFD9418067CE45406A66D24B31FC0E400111871167CE45408BEE0F4A4EFC0E400702092F66CE4540A4CBF67C28FC0E40924DA89663CE4540BDFF8F1326FC0E40CDDB227A63CE45408120E5CC1BFC0E40F7B6F4C363CE454010429B77F7FB0E401C237E6A61CE454031395A7AD9FB0E40B052E68B62CE45402B22799DC3FB0E4032E94A5F63CE45400500000008628F3F07FC0E40A39EF47464CE45406D8C9DF012FC0E401A8DD71764CE45401316CBE31FFC0E40D80DDB1665CE454019B61C9E14FC0E407F66B56565CE454008628F3F07FC0E40A39EF47464CE4540	r1226975	1226975	relation	yes	\N	\N	\N	\N
4	0106000020E61000000100000001030000000300000030000000244AD63CA2FD0E40470B862980CE4540D7506A2FA2FD0E407D66FFF27FCE4540CE16B5A09CFD0E407100FDBE7FCE4540516C6006BEFD0E402D24607479CE4540787709F3C3FD0E40C2E3367579CE4540B439CE6DC2FD0E40E61B768478CE454009104FC0C0FD0E401C63827577CE4540038DE3D1D7FD0E40E7ABE46377CE4540832B4597DCFD0E40F9D4569176CE45401184D0E6DDFD0E4046729E5676CE45408DA2BDB0EBFD0E40EE601FF873CE4540163E117AECFD0E40AD7191D673CE4540E4E59FCF36FD0E40B905A62E74CE45403BC20E0819FD0E40307EBF3D74CE4540A0956A5501FD0E40BF38A74874CE454065B9B601E9FC0E4077723C5574CE4540BF3F4A9121FC0E407D0162B774CE454092578C5F1DFC0E40A7800FB974CE45401805C1E3DBFB0E40BEF0EFD874CE45409DE6D319CEFB0E40A0A932E774CE4540BCF781F5C9FB0E40DC65BFEE74CE4540701EF3A6C7FB0E4059E3C7F374CE4540D74BF84AC5FB0E4053DED8FD74CE4540A9633A19C1FB0E40C451031775CE45402E8210DABCFB0E409A00683975CE45402AE5B512BAFB0E4053680F6A75CE45404E93BEB5B8FB0E40884DBF9F75CE4540CF143AAFB1FB0E40DC792CC775CE45401B62612DE3FB0E4056270C6F7BCE4540398DFEE1F8FB0E40DDEA39E97DCE45402DDED9684AFC0E406D86C03687CE454090AB47D04EFC0E40F6C5EFB787CE45400B3BD6D699FC0E40C80E852A90CE454072361D01DCFC0E40B76114048FCE4540280CCA349AFC0E406DE2E47E87CE45405AAEC8F9ACFC0E40CD8EF92587CE45407742F9CCA3FC0E40FDD0162186CE4540F123230CA8FC0E4009DBF40C86CE454015EC1A88C0FC0E40C719790F86CE45407EB38300CFFC0E40E30C0FAB89CE45407390C657F1FC0E406C38D15389CE454009C95DDFE2FC0E40862AEBED85CE4540F0B1AA14F1FC0E40CDF055E185CE45401BEB2CC434FD0E40F10EF0A485CE454098F738D384FD0E405DF3F45B85CE454032CA332F87FD0E405DF3F45B85CE454065A9F57EA3FD0E40B2E9526D81CE4540244AD63CA2FD0E40470B862980CE4540070000004FC0C0BD7CFC0E404E5E64027ECE454077EB466980FC0E40523D3EC681CE45405E9AC70677FC0E40BEAB79E981CE4540283E88AE55FC0E40C532A2597ECE4540EA78CC4065FC0E401F36EC527ECE4540E4BB94BA64FC0E400798F90E7ECE45404FC0C0BD7CFC0E404E5E64027ECE4540050000002E724F5777FC0E40C85EEFFE78CE454003E7316F7AFC0E4079B537537CCE4540AE5F556243FC0E4079E349777CCE4540179348EC24FC0E40FE439F3479CE45402E724F5777FC0E40C85EEFFE78CE4540	r1226986	1226986	relation	yes	Université de Montpellier - Faculté de Médecine	university	fr:Faculté de Médecine de Montpellier	0
5	0106000020E6100000010000000103000000030000001D000000F3F1BF4B5FFE0E40B4F116FEC2CE454061399DBF64FE0E403D03345BC3CE454075CDE49B6DFE0E409C397F6EC3CE45401465259CCCFE0E40794F2F42C2CE4540EE76627BD2FE0E409768DA0FC2CE4540046B4194D4FE0E407997E6B1C1CE454096AFCBF09FFE0E40DA04734FB2CE4540D4916D2A9CFE0E407BA01518B2CE45407781374998FE0E40635E471CB2CE4540AD86C43D96FE0E40229DCB1EB2CE4540104C24873EFE0E400F5AB4A5B3CE4540224CF6741AFE0E40DC6C077EAFCE454007BBBC9415FE0E40717495EEAECE454043609B4308FE0E405A38FF65ADCE4540B8DB3F602FFE0E40EF6D9FFAACCE454056F9F94A7BFE0E40C0D5952AACCE4540181758117FFE0E40C6DA8420ACCE45400EA0DFF76FFE0E403255302AA9CE45405445A79D50FE0E40ADE52906A3CE4540A6A1A1DA3BFE0E4002AE75F39ECE4540A290AEE309FE0E407FE3C6889FCE454058F7D91203FE0E4073D9E89C9FCE45400541367F02FE0E4031EA5A7B9FCE4540711E4E603AFD0E4078EC0CF8A1CE4540A437DC476EFD0E403FC16AD1A7CE45408FA09D7873FD0E4051B69267A8CE4540231521D0F4FD0E407FEF80FCB6CE4540D34F937428FE0E403487FFCFBCCE4540F3F1BF4B5FFE0E40B4F116FEC2CE45400F000000D6389B8E00FE0E4026A77686A9CE45406A1492CCEAFD0E400289DCC2A9CE4540F98CFADAE9FD0E40FDCBA43CA9CE45405523AAA6DAFD0E4097BE7C57A9CE4540349B6CA8BDFD0E40B13ACD5DA6CE4540B18284CDA5FD0E40D07355EAA3CE45403B63A93F0CFE0E4071CD78B6A2CE454074C5D67D11FE0E40C40D53B6A3CE4540CFCF1E7931FE0E409748B3C3A9CE454014AFB2B629FE0E40CDFF50D5A9CE4540DE8C3FF61FFE0E40C2CD9838A8CE45404A5A965412FE0E405D0828C3A7CE45401798BAD001FE0E4045F46BEBA7CE45401AF8510DFBFD0E40C82EAC76A8CE4540D6389B8E00FE0E4026A77686A9CE454009000000EBD7E77B57FE0E402A2D6D82B9CE45407E9301FB43FE0E40C63F225CB7CE4540633C94B256FE0E4079EA9106B7CE45402B172AFF5AFE0E407874C872B7CE4540EE714B5068FE0E40F090BD39B7CE4540581CCEFC6AFE0E40FB24D291B7CE4540BC26FFEE78FE0E4043BD2A61B7CE45407F445DB57CFE0E40FB1E9A1EB9CE4540EBD7E77B57FE0E402A2D6D82B9CE4540	r3697544	3697544	relation	yes	Université de Montpellier - Institut de Biologie	university	\N	\N
6	0106000020E610000001000000010300000002000000230000001BD423B2B4F80E40C7D056CAD7CE45408FF51E78C6F80E40FBF14D89DACE454086151340D6F80E408A22FF27DACE454047776BF4C5F90E408DC41561D4CE45406E8214E1CBF90E40220E23CED4CE45405925A2A9E8F90E403465A71FD4CE454063DBFD8579FA0E40129B34B2D0CE454018224CF674FA0E40784C384FD0CE4540D9DD4D017AFB0E4069273916CACE454091813CBB7CFB0E40B64EB747CACE4540BA26497C93FB0E400A95C9BAC9CE454052D66F26A6FB0E40CF4E0647C9CE4540C1035EC191FB0E40C9213DA0C7CE4540042CA85E6DFB0E40DBA09BA2C8CE454041D47D0052FB0E40706072A3C8CE454071FCF5AF51FB0E40D310FA3EC1CE45408B822A7F08FB0E40260F5542C1CE454008A40E3C08FB0E4099DF1FA5C8CE4540753282D778FA0E405219B5B1C8CE454010255AF278FA0E404080B163C8CE4540EAE2DB604DFA0E407C3C3E6BC8CE454050F003464DFA0E402D7F19E7CACE45405FC5F363DDF90E40693BA6EECACE45408473FC06DCF90E40BDFDB968C8CE4540650E93BAAEF90E40E1777874C8CE4540B207FFC7AEF90E401C9029C4C8CE454001BD70E7C2F80E40B14F00C5C8CE454037A2201DC3F80E40DB72897EC8CE45407ACD61AD90F80E40ABEEEC86C8CE454081AA76F28EF80E4080773C77CCCE4540EBFD463B6EF80E40BB33C97ECCCE454073B389DD88F80E4018CE35CCD0CE45404B901150E1F80E40545CB0AFD0CE4540B65A71BBE1F80E4039A6DD9ED6CE45401BD423B2B4F80E40C7D056CAD7CE4540050000003C81559A39F90E4054E6E61BD1CE454084BD892139F90E4091860959CCCE454020E05A37EFF90E402C4BCF4FCCCE4540D9A326B0EFF90E4059EBD511D1CE45403C81559A39F90E4054E6E61BD1CE4540	r3720135	3720135	relation	yes	Institut de Botanique	\N	\N	\N
7	0106000020E6100000010000000103000000030000005200000087414FB978FE0E403BB885F8D1CE454074EACA6779FE0E4000FCF8F0D1CE4540D9D7158E7BFE0E407D4BEFD1D1CE454007E0B07E7DFE0E40D01B38B1D1CE4540B309302C7FFE0E4065ADFC8DD1CE4540DC54939680FE0E40FA3EC16AD1CE4540CFBA46CB81FE0E40D0910145D1CE45404042DEBC82FE0E40A7E4411FD1CE4540E1F1ED5D83FE0E40E877ABF8D0CE45404BBC4DC983FE0E40954B3ED1D0CE4540E6AE25E483FE0E40AD5FFAA8D0CE4540FEC2E1BB83FE0E405A338D81D0CE454093F8815083FE0E400707205AD0CE4540A54F06A282FE0E40489A8933D0CE454035C86EB081FE0E401EEDC90DD0CE45404162BB7B80FE0E40F53F0AE8CFCE4540CB1DEC037FFE0E408AD1CEC4CFCE4540D2FA00497DFE0E40B4226AA2CFCE4540A3F265587BFE0E4007F3B281CFCE45403F051B3279FE0E408442A962CFCE4540A53220D676FE0E40C0D02346CFCE45402474E15174FE0E40BA9D222CCFCE45406DD0F29771FE0E40DDE9CE13CFCE4540CD40C0B56EFE0E405534D6FECECE454046C549AB6BFE0E408ABD61ECCECE45407150679368FE0E407E8571DCCECE4540B4EF405365FE0E40C64BDCCFCECE4540AA95AE0562FE0E40CC50CBC5CECE45405342B0AA5EFE0E40255415BFCECE4540AEF545425BFE0E40D255BABBCECE454009A9DBD957FE0E40D255BABBCECE4540645C717154FE0E4090943EBECECE45400C09731651FE0E403791F4C4CECE454002AFE0C84DFE0E409CCC2ECECECE4540454EBA884AFE0E40C046EDD9CECE454023E06B6347FE0E4037BF06E9CECE45409C64F55844FE0E4001367BFBCECE4540AFDB566941FE0E408AEB7310CFCE4540F83768AF3EFE0E403D201A27CFCE4540F27A30293EFE0E40E31CD02DCFCE4540F25D4A5D32FE0E4061E28FA2CECE45403040EC962EFE0E40070D58CDCECE45402FE6424019FE0E409D8AAFD1CDCE454028092EFB1AFE0E403D5464BECDCE45405951836918FE0E40BBA35A9FCDCE4540C1D31A39C1FD0E402AF16F86D1CE45400BA2A47675FD0E40FCEE0C09CECE4540D7F9B7CB7EFD0E409124AD9DCDCE45409BA6745545FD0E406336B7F8CACE45401937DA160AFD0E40BBA35A9FCDCE45402CCB21F312FD0E40D26F5F07CECE45400CE71A6668FC0E400AE0C1AAD5CE4540217E593563FC0E40047FAE6CD5CE4540351598045EFC0E40289D4830D5CE45402CDBE27558FC0E40577D0970D5CE45401844A4A65DFC0E40335F6FACD5CE4540C3503D8853FC0E406FA53220D6CE45407F1DEED929FC0E40D33659FED7CE454042AFE4CF5CFC0E40AECACF57DACE454078D1579066FC0E405B423EE8D9CE45404BFECCC584FD0E4048EEFA16E7CE454062D5C5127BFD0E409B768C86E7CE45401FCA6141ABFD0E40351B75BEE9CE45406DA6E7829FFD0E403BD8AC44EACE454026E1421EC1FD0E40A5129ED0EBCE454075ABE7A4F7FD0E40EECAD35EE9CE45406B1789BFDCFD0E402AE9BC21E8CE45400CE47E2CE9FD0E4054B02193E7CE454076711B0DE0FD0E40E9E5C127E7CE4540F82290018FFE0E40644EE152DFCE4540173147EA98FE0E4034547BC7DFCE45401BEB877DA7FE0E4082678C20DFCE4540A63A2EF4D2FE0E402AE0432EDDCE454094522BA798FE0E406C37667EDACE4540284B08B18EFE0E40E93EA5EFDACE45404E6B894B44FE0E40C7743282D7CE45403ABF72CE99FE0E40B75D68AED3CE454011740F6498FE0E4082A6CA9CD3CE454023CB93B597FE0E40BD6257A4D3CE4540C440D7BE80FE0E4088693A96D2CE45402EEB596B83FE0E4005B93077D2CE454087414FB978FE0E403BB885F8D1CE454005000000E5CBB0F61CFD0E40D72FD80DDBCE4540128F7A3EB9FC0E40BCFAC275D6CE4540558A1D8D43FD0E407E512745D0CE454027C75345A7FD0E4004C765DCD4CE4540E5CBB0F61CFD0E40D72FD80DDBCE4540050000007ACC9B1E6FFD0E40C4CCE3D5DECE454008A1CDBBFBFD0E40EB30708AD8CE4540B84FD88F5EFE0E4077AB9D17DDCE4540297BA6F2D1FD0E4050471163E3CE45407ACC9B1E6FFD0E40C4CCE3D5DECE4540	r3728883	3728883	relation	yes	Université Montpellier 3 : Site de Saint-Charles	university	\N	\N
8	0106000020E6100000010000000103000000010000000A0000002C82FFAD64F70E402140E14790CE4540E7C2482F6AF70E4099D29FA28FCE4540591822A7AFF70E401F2BF86D88CE45407C32B55B81F70E40A3F5A6D887CE45401A7D16951EF70E40938B31B08ECE454080AA1B391CF70E40EDBC8DCD8ECE4540CDF22B8CE3F60E408A88073994CE454029E384AEE9F60E4055FF7B4B94CE45400520A45D3BF70E407E92962595CE45402C82FFAD64F70E402140E14790CE4540	r7679883	7679883	relation	yes	Ancien rectorat et Ancienne intendance du jardin des plantes	\N	\N	\N
9	0106000020E6100000010000000103000000010000000B0000004A9C700A86FE0E403E2883FE9DCE4540587380608EFE0E4043273A819FCE4540A469F57A9CFE0E405B3BF6589FCE454070C108D0A5FE0E4025AC32F8A0CE454042BC64D295FE0E402BDF3312A1CE4540CA37DBDC98FE0E40B3A899FFA1CE4540C663AB7070FE0E4006312B6FA2CE4540ED516E916AFE0E4090A4A487A1CE45407DCAD69F69FE0E405BC52CC59FCE45404128EFE368FE0E40203DEA549ECE45404A9C700A86FE0E403E2883FE9DCE4540	w75319734	75319734	way	yes	\N	\N	\N	13
10	0106000020E61000000100000001030000000100000007000000695B28F455FD0E40FEFEDEB76BCE4540D8FCAEBE70FD0E4010E099756BCE454005C58F3177FD0E40DAF4B1CC6CCE4540D11F9A7972FD0E40516DCBDB6CCE454082E673EE76FD0E4063BE17BA6DCE45402B966C8665FD0E4045A56CEC6DCE4540695B28F455FD0E40FEFEDEB76BCE4540	w75319735	75319735	way	yes	\N	\N	\N	7
11	0106000020E6100000010000000103000000010000000F000000CB87FB2367FC0E40FC3FE2B265CE45400B8D710F53FC0E40E916708566CE45408BEE0F4A4EFC0E400702092F66CE4540A4CBF67C28FC0E40924DA89663CE4540BDFF8F1326FC0E40CDDB227A63CE45408120E5CC1BFC0E40F7B6F4C363CE454010429B77F7FB0E401C237E6A61CE45400725CCB4FDFB0E4069C0C52F61CE4540EF2DF6A809FC0E4081785DBF60CE454008B941A32AFC0E4086014BAE62CE45408737C6A931FC0E4039DACC7C62CE4540EFA18ED838FC0E40D356DB0363CE45406E2013DF3FFC0E4003AD65D762CE454036FBA82B44FC0E4003098A1F63CE4540CB87FB2367FC0E40FC3FE2B265CE4540	w75319877	75319877	way	yes	\N	\N	\N	17
12	0106000020E61000000100000001030000000100000013000000C1AE8108CCFE0E40BB911E2B9DCE4540AE3720F8CEFE0E4038C76FC09DCE45403810374CD9FE0E4031186D9F9FCE4540DB3CC4F5DEFE0E4025E07C8F9FCE4540941D763AEBFE0E407EC3E9C9A1CE4540575BB1BFECFE0E40771A1F1CA2CE45407BE9DCA3EDFE0E40771A1F1CA2CE45402BB0B618F2FE0E40ADB717E2A2CE4540A99AC530CCFE0E40DCC5EA45A3CE45405C4AA7BFA8FE0E4065D707A3A3CE4540BFFA2E5BA1FE0E40FA9C1617A2CE45400BF1A375AFFE0E40F56915FDA1CE45407EB8F5E4ABFE0E40AE3319E9A0CE454070C108D0A5FE0E4025AC32F8A0CE4540A469F57A9CFE0E405B3BF6589FCE4540587380608EFE0E4043273A819FCE45404A9C700A86FE0E403E2883FE9DCE4540948CF73EB0FE0E40DF67017F9DCE4540C1AE8108CCFE0E40BB911E2B9DCE4540	w75319913	75319913	way	yes	\N	\N	\N	13
13	0106000020E6100000010000000103000000010000000700000060CF32E609FF0E4004842051B2CE45404A18175811FF0E409E9ED21CB4CE45403767E9AFFCFE0E4098C7F54AB4CE45406CD509C3DBFE0E4080E14B97B4CE4540FC6D4F90D8FE0E4063580FA9B3CE45405DDE1CAED5FE0E40E0C1AAD5B2CE454060CF32E609FF0E4004842051B2CE4540	w75319951	75319951	way	yes	\N	\N	\N	10
14	0106000020E6100000010000000103000000010000000B0000005418004FFFFE0E40804E9C37A9CE45401C107C670FFF0E401F268689ABCE4540D79F692EDCFE0E40BAD0A634ACCE4540B6FA4564B3FE0E4025F72AE8ACCE4540389C9E1CAAFE0E40BA185EA4ABCE45401ACBAABEA9FE0E406D1FF296ABCE4540363FFED2A2FE0E40851F4196AACE454021E28B9BBFFE0E40F0D53329AACE4540D79F692EDCFE0E40F14BFDBCA9CE454053DB3CC4F5FE0E40807CAE5BA9CE45405418004FFFFE0E40804E9C37A9CE4540	w75319956	75319956	way	yes	\N	\N	\N	13
15	0106000020E6100000010000000103000000010000000D0000005FAF55270CFF0E407093F6ABA5CE45400F762F9C10FF0E401CA90881A6CE4540C91F0C3CF7FE0E40F2857FC7A6CE4540E3569CC5E6FE0E40D46CD4F9A6CE4540955A39C5F4FE0E403FA7C585A8CE4540F16261889CFE0E40568737C6A9CE454043DC419193FE0E40B0BECB56A8CE4540A8ACA6EB89FE0E40DA43B1CBA6CE454026620097B6FE0E401043064DA6CE4540247CEF6FD0FE0E40A5A6B805A6CE454079C9FFE4EFFE0E40C39151AFA5CE4540A12E52280BFF0E40EDB4DA68A5CE45405FAF55270CFF0E407093F6ABA5CE4540	w75320074	75320074	way	yes	\N	\N	\N	15
16	0106000020E61000000100000001030000000100000010000000DE5DC2FC70FB0E40032670EB6ECE45409AD8D7158EFB0E4080EB2F606ECE45401CD4D9249AFB0E407451E3946FCE4540105F814303FC0E408C99E9036ECE454022F0D12C1AFC0E4037BD303E71CE4540B72572C119FC0E40F629C76471CE45408EDA0E5718FC0E40CCD82B8771CE45404201800816FC0E40A88C7F9F71CE4540F06AB93313FC0E401F0599AE71CE4540235F5331DFFB0E40EF38454772CE4540A56F2DEE9AFB0E40E314C20F73CE454053D9661998FB0E40FB56900B73CE4540B9066CBD95FB0E40199E4DFD72CE45408BFED0CC93FB0E403CEAF9E472CE4540394B242C85FB0E40BA3F283971CE4540DE5DC2FC70FB0E40032670EB6ECE4540	w75320153	75320153	way	yes	\N	\N	\N	18
17	0106000020E61000000100000001030000000100000006000000292499D53BFC0E4067FF4D3970CE4540A5B107A40EFC0E401D4CD41C6ACE454094D1127530FC0E40DC0022B369CE45404B75012F33FC0E40888CFD1B6ACE4540EA5BE67459FC0E40A331A4D46FCE4540292499D53BFC0E4067FF4D3970CE4540	w75320223	75320223	way	yes	\N	\N	\N	6
18	0106000020E610000001000000010300000001000000080000002D2A3D2E05FF0E40ACFCD75EB0CE4540278AEB7310FF0E408D0B0742B2CE454060CF32E609FF0E4004842051B2CE45405DDE1CAED5FE0E40E0C1AAD5B2CE45401D9FDA2AD2FE0E40BD056DCDB1CE45409CE09BA6CFFE0E40C324010FB1CE454090BDDEFDF1FE0E40461DC29DB0CE45402D2A3D2E05FF0E40ACFCD75EB0CE4540	w75320240	75320240	way	yes	\N	\N	\N	11
19	0106000020E6100000010000000103000000010000001B000000CB97BCA6ACFB0E4005DCF3FC69CE454014D7E7209EFB0E40D72F7D5468CE454043C29C4594FB0E40A1D4038B68CE45401D7D27C176FB0E4006C8862469CE4540E1F725D181FB0E40F92D3A596ACE454016A0127C78FB0E404755B88A6ACE454083C7123180FB0E40D5230D6E6BCE45403DE87EF387FB0E40CF328B506CCE45406CD333187EFB0E409FDC007D6CCE45409AD8D7158EFB0E4080EB2F606ECE4540DE5DC2FC70FB0E40032670EB6ECE4540924A671657FB0E4075A50AEB6BCE4540D14CE60E51FB0E4034FE33396BCE4540198C118942FB0E400652BD9069CE45405B0B0E8A41FB0E404DEA156069CE45400E12A27C41FB0E402942453069CE4540375D05E742FB0E4071DA9DFF68CE45403CFA5FAE45FB0E401EAE30D868CE454079509A1771FB0E40C5B01E5267CE4540D5B48B69A6FB0E40CC5F217365CE4540CA77DFE7AEFB0E40BA22426D65CE454097EFCFFBB5FB0E40490B3C9C65CE454028FFA4EBD3FB0E4083BB58BD68CE4540E1C27064D4FB0E40E2F1A3D068CE4540AA8317D8BEFB0E40773BB13D69CE4540914F7E41C1FB0E40F414DE8A69CE4540CB97BCA6ACFB0E4005DCF3FC69CE4540	w75320263	75320263	way	yes	\N	\N	\N	16
20	0106000020E61000000100000001030000000100000009000000CA37DBDC98FE0E40B3A899FFA1CE454082FBA65599FE0E4072153026A2CE4540BFFA2E5BA1FE0E40FA9C1617A2CE45405C4AA7BFA8FE0E4065D707A3A3CE4540C817FE1D9BFE0E40FAC4F0C7A3CE45404A7F8A3E7AFE0E402FD8B221A4CE4540DC37ADCA74FE0E405310F230A3CE4540C663AB7070FE0E4006312B6FA2CE4540CA37DBDC98FE0E40B3A899FFA1CE4540	w75320404	75320404	way	yes	\N	\N	\N	13
21	0106000020E6100000010000000103000000010000000A000000C1AE8108CCFE0E40BB911E2B9DCE454091C0D5F0E3FE0E40277623E29CCE4540C91F0C3CF7FE0E4074136BA79CCE4540C93CF20703FF0E40F04284C99ECE4540E390685DFEFE0E40EA3D95D39ECE45405F926F5B00FF0E40BA432F489FCE4540DB3CC4F5DEFE0E4025E07C8F9FCE45403810374CD9FE0E4031186D9F9FCE4540AE3720F8CEFE0E4038C76FC09DCE4540C1AE8108CCFE0E40BB911E2B9DCE4540	w75320435	75320435	way	yes	\N	\N	\N	12
22	0106000020E61000000100000001030000000100000009000000EF7CF5A743FD0E40DBE044F46BCE45406A41391B3CFD0E40CFD666086CCE45407FF0468BD8FC0E406306CF296DCE4540C26A2C616DFC0E40AA6ADD616ECE454025FECD305AFC0E40826D69DA6ACE4540DA17755204FD0E40475BF0FD68CE4540007AD0A22DFD0E408F97248568CE4540522D7D433CFD0E406AFD88BA6ACE4540EF7CF5A743FD0E40DBE044F46BCE4540	w75320458	75320458	way	yes	\N	\N	\N	15
23	0106000020E61000000100000001030000000100000005000000BD569D30BCFD0E40662728EA71CE4540D87047EE9FFD0E401357DF0A72CE454095B4876297FD0E405C3D27BD6FCE454004560E2DB2FD0E40F7A5C86B6FCE4540BD569D30BCFD0E40662728EA71CE4540	w75320504	75320504	way	yes	\N	\N	\N	2
24	0106000020E610000001000000010300000001000000180000002DA17197B3FD0E402DAB55606DCE45405232946EA6FD0E40A5715E526BCE45400353173AC0FD0E40DB9EC5F76ACE4540F4215E8DA2FD0E40F57C72B966CE4540E17030E58DFD0E40B3171B0467CE4540ADAB5D6E8BFD0E40D707A3A366CE45406B0F7BA180FD0E40BFF3E6CB66CE454034ED07E176FD0E401A2B7B5C65CE45403C5E9214A2FD0E4091BD39B764CE4540996EC8F5A5FD0E402535594865CE45406A317898F6FD0E4056911B8F63CE4540A61023DF00FE0E40BAC61D2565CE45405FD4EE5701FE0E40B4C12E2F65CE454040E31D3B03FE0E402002582E65CE4540C65B9D5214FE0E4054F53CC967CE45402149FF8128FE0E40019BBD7D67CE4540C8F2093433FE0E4024E131F268CE4540F7FAA42435FE0E402942453069CE4540C455AF6C30FE0E40A0BA5E3F69CE4540A581C41B3EFE0E4016E5886B6BCE45408E194DD30CFE0E40B794980C6CCE45407E6E0D11DCFD0E406FB488CD6CCE454037FB03E5B6FD0E402DAB55606DCE45402DA17197B3FD0E402DAB55606DCE4540	w75320551	75320551	way	yes	Hôtel de Fesquet	\N	\N	16
25	0106000020E61000000100000001030000000100000011000000BEEF294A53FE0E40F95F538C98CE4540081D740987FE0E40949AE21698CE4540C59A801596FE0E40ACAE9EEE97CE4540EEE5E37F97FE0E40D0566F1E98CE45403E3CF0D69EFE0E40587CF95399CE4540884C54CAC6FE0E4005F467E498CE4540A97DDF64C0FE0E40F446F7BD97CE45402FB99BF1C7FE0E40E80E07AE97CE45406B7B606CC6FE0E40897C975297CE45403BC780ECF5FE0E4024B726DD96CE4540FA84477600FF0E406A430FC699CE4540D156CAD70AFF0E40E18D16B199CE4540C39CA04D0EFF0E40102620819ACE4540C663AB7070FE0E40450598439CCE4540EE5465845CFE0E40F24EF4AF9BCE454050E50F6157FE0E407CAE00F099CE4540BEEF294A53FE0E40F95F538C98CE4540	w75320637	75320637	way	yes	\N	\N	\N	19
26	0106000020E6100000010000000103000000010000001200000046A68D3402FB0E40DA756F4562CE45406391706B1CFB0E40D45C137761CE45402849320631FB0E406964A1E760CE45400398327040FB0E406FDF597160CE45408113C08355FB0E40222EA5D35FCE45402137685485FB0E401518570163CE45408AC10D428AFB0E402669A3DF63CE4540F9B42F455EFB0E4091A3946B65CE45401392167838FB0E409C7928C066CE4540184F4EFE38FB0E403C9F01F566CE4540C7B8872936FB0E40369A12FF66CE4540238CFA7F30FB0E4048D7F10467CE45400ED8D5E429FB0E407E607DF266CE45406AAB483B24FB0E40DD3AA4BD66CE45403CA3AD4A22FB0E409C4B169C66CE4540698B6B7C26FB0E40CCA1A06F66CE45401A18795913FB0E40443A973D64CE454046A68D3402FB0E40DA756F4562CE4540	w75320642	75320642	way	yes	\N	\N	\N	20
27	0106000020E61000000100000001030000000100000018000000A56950340F000F4036A6CC727ECE4540CC57135509000F40D7B1005C7FCE45403DE2A139FCFF0E40182BC5E97FCE4540ED4ED257EBFF0E4095D6DF1280CE4540B4CFBE4DDAFF0E40A1B2ABDA7FCE454059FF42EAD1FF0E406067F9707FCE45407A30CE84CBFF0E40FACF9A1F7FCE4540EB9A7FAAC0FF0E40A8F11CDB7CCE4540BAF369BA43FF0E4096DC17867ECE45402995F0845EFF0E40812B346B84CE4540398FD48C56FF0E40DA5C908884CE45407B0ED18D55FF0E40BCB9AE4E84CE4540935742D202FF0E4021DB430C85CE45403DCD6ED2D9FE0E4090AF4EDF7CCE4540066E3887C6FE0E408AD8710D7DCE4540295316CFEAFE0E40BCF8ECCA78CE45401CF3959B03FF0E4023CACD2676CE454022B8DB3F60FF0E401630815B77CE45404FF74BD587FF0E40CF97288C77CE454064C8563C9AFF0E400A54B59377CE45406625F785A1FF0E407594DE9277CE4540A4F2C011EEFF0E40F816D68D77CE4540955286600B000F40EFCBF4A67DCE4540A56950340F000F4036A6CC727ECE4540	w75320672	75320672	way	yes	\N	\N	\N	15
28	0106000020E6100000010000000103000000010000000A00000021E28B9BBFFE0E40E8BE9CD9AECE454043A78C24E6FE0E4095360B6AAECE454022CDB3ED0FFF0E40E3772EE7ADCE4540E04DB7EC10FF0E40A1E4C40DAECE4540ED24C74219FF0E401D5C959FAFCE454072439D0315FF0E40AC167DAAAFCE454053DB3CC4F5FE0E40536F57F9AFCE45409F4033E3C8FE0E40CF76966AB0CE454001D1DDBFC3FE0E402966738BAFCE454021E28B9BBFFE0E40E8BE9CD9AECE4540	w75320676	75320676	way	yes	\N	\N	\N	12
29	0106000020E6100000010000000103000000010000000A00000089F83DA022FD0E405EF7B1DD98CE4540135DBCC4FDFC0E40ED97F49C99CE4540C84C58D1D5FC0E402B1E728E95CE4540CC5D4BC807FD0E4084DF3C8B94CE45405BB6D61709FD0E405B8EA1AD94CE45409D52B9E413FD0E408A82CFC595CE45409EAC623B29FD0E40CBB9145795CE4540FFB0A54753FD0E40ED97F49C99CE4540BDDAF6E230FD0E40C3FEA14F9ACE454089F83DA022FD0E405EF7B1DD98CE4540	w75320679	75320679	way	yes	Tour des Pins	\N	fr:Tour des Pins (Montpellier)	21
30	0106000020E610000001000000010300000001000000050000006635B808E7FE0E402B77555689CE45403A162532BDFE0E409641B5C189CE454042131736B9FE0E4090FA46CF88CE4540FDAA121BE2FE0E40376DC66988CE45406635B808E7FE0E402B77555689CE4540	w75320688	75320688	way	yes	\N	\N	\N	3
31	0106000020E6100000010000000103000000010000000E000000CB97BCA6ACFB0E4005DCF3FC69CE4540914F7E41C1FB0E40F414DE8A69CE4540AA8317D8BEFB0E40773BB13D69CE4540E1C27064D4FB0E40E2F1A3D068CE454028FFA4EBD3FB0E4083BB58BD68CE4540898C58D5DCFB0E409BCF149568CE4540D3252DA6E3FB0E400B57AC8669CE454083C7123180FB0E40D5230D6E6BCE454016A0127C78FB0E404755B88A6ACE4540E1F725D181FB0E40F92D3A596ACE45401D7D27C176FB0E4006C8862469CE454043C29C4594FB0E40A1D4038B68CE4540FA8271CBA2FB0E405303722E6ACE4540CB97BCA6ACFB0E4005DCF3FC69CE4540	w75320757	75320757	way	yes	\N	\N	\N	10
32	0106000020E6100000010000000103000000010000000A000000D770EC342DFC0E404EF04DD367CE45401A10C6F429FC0E40BF6378EC67CE4540BC8800F104FC0E40B36D07D968CE4540D9FF4AF8EFFB0E40F534BB4967CE454027FCADF8E1FB0E403DB9A64066CE4540ADAEF9A70AFC0E40974C5F1965CE4540FCE4284014FC0E4073B8FBC165CE4540AA4E626B11FC0E404F6C4FDA65CE45407F1DEED929FC0E40CB11329067CE4540D770EC342DFC0E404EF04DD367CE4540	w75320764	75320764	way	yes	\N	\N	\N	19
33	0106000020E6100000010000000103000000010000002D0000008714A86A27FF0E407F8F55A588CE454084D4EDEC2BFF0E404E4D38AA89CE45402244431031FF0E40545227A089CE45400D8D278238FF0E40B98729368BCE454018B0E42A16FF0E401E1F88878BCE45408D0EA37B31FF0E401502B9C491CE4540651DE96745FF0E4078FD385096CE45405853FE5A03000F40F01F668A94CE454026CEE561FCFF0E40A93121E692CE4540D8D47954FCFF0E4032B907D792CE4540C67DF502FDFF0E40BB40EEC792CE45400120DDBEFDFF0E405605B4BE92CE4540E22E0CA2FFFF0E40DF8C9AAF92CE4540BE8003FF00000F40F6CE68AB92CE45409F8F32E202000F40795160A692CE4540DD96C80567000F40B5CB6DB191CE4540DDD0949D7E000F4090E3E20396CE45402ACA00AB7E000F406C97361C96CE45402ACA00AB7E000F40484B8A3496CE4540BA4269B97D000F40A781D54796CE4540DEF0715C7C000F4006B8205B96CE4540D156CAD70AFF0E40E18D16B199CE4540FA84477600FF0E406A430FC699CE45403BC780ECF5FE0E4024B726DD96CE45406B7B606CC6FE0E40897C975297CE45402FB99BF1C7FE0E40E80E07AE97CE4540A97DDF64C0FE0E40F446F7BD97CE4540EEE5E37F97FE0E40D0566F1E98CE4540C59A801596FE0E40ACAE9EEE97CE4540081D740987FE0E40949AE21698CE4540D1DA238A7FFE0E40FB7F304B96CE45407D7B325AA2FE0E4096E8D1F995CE4540C23AE9D89CFE0E405B8EA1AD94CE4540173147EA98FE0E409103C0C293CE454053F30B6597FE0E40C630276893CE454088612C7876FE0E40AE4A7DB493CE4540133D3ABF72FE0E401A7739DB92CE45409E1848066FFE0E4086A3F50192CE4540FE19941FA7FE0E40442A317491CE454048D04EBCB9FE0E40B641374591CE45409572086696FE0E403120200489CE454042131736B9FE0E4090FA46CF88CE45403A162532BDFE0E409641B5C189CE45406635B808E7FE0E402B77555689CE45408714A86A27FF0E407F8F55A588CE4540	w75320800	75320800	way	yes	Université de Montpellier - Faculté de Droit et Science Politique	university	\N	25
34	0106000020E61000000100000001030000000100000022000000A581C41B3EFE0E4016E5886B6BCE4540C455AF6C30FE0E40A0BA5E3F69CE4540F7FAA42435FE0E402942453069CE4540C8F2093433FE0E4024E131F268CE4540DBA337DC47FE0E40CA81C3B068CE45406FD6E07D55FE0E40E89A6E7E68CE45401C203DEA54FE0E4077CB1F1D68CE454068F9CB3857FE0E408379D9C067CE4540B4D25A8759FE0E40C50C439A67CE4540B96FB54E5CFE0E406CDBE67C67CE454038EE395563FE0E409C31715067CE4540ACD568835DFE0E404F52AA8E66CE45400292FAFC41FE0E40EB50F28F63CE4540F37D271C30FE0E405D120C8C61CE454055826A285AFE0E40AB11B00C60CE4540C45DBD8A8CFE0E40E4874A2366CE454042F6306AADFE0E409632BACD65CE4540D9887148B4FE0E404EAECED666CE45405721E527D5FE0E40A827E26366CE45400A28791AD5FE0E4049F1965066CE45409E3D3CF0D6FE0E401911D61066CE4540A2DA96B7D9FE0E40DE2637E565CE454065F8F47DDDFE0E406DB30CCC65CE454028165344E1FE0E40F63AF3BC65CE4540C685A867E6FE0E4073B8FBC165CE454046240A2DEBFE0E401FE8B2E265CE4540E0F60489EDFE0E4061D7400466CE4540563BD400EFFE0E401F44D72A66CE45405CF80B87EFFE0E409618158266CE4540D053D3E418FF0E407E1EFEF565CE45400E901E752AFF0E401E520C9068CE4540984638D2BEFE0E4017BDAEBA69CE45401E4828C7AEFE0E404DA25EF069CE4540A581C41B3EFE0E4016E5886B6BCE4540	w75320865	75320865	way	yes	\N	\N	\N	11
35	0106000020E6100000010000000103000000010000000700000026620097B6FE0E401043064DA6CE4540A8ACA6EB89FE0E40DA43B1CBA6CE45404042DEBC82FE0E40ED10FFB0A5CE4540CC3DC9C27CFE0E4023861DC6A4CE4540C1FD254E93FE0E402F62E98DA4CE4540DE08E643ABFE0E4053808351A4CE454026620097B6FE0E401043064DA6CE4540	w75320999	75320999	way	yes	\N	\N	\N	14
36	0106000020E6100000010000000103000000010000000B0000008293C89981F50E4023A875768DCE454065A5EE6F75F50E40ACB992D38DCE454018A76B370BF50E408C6665FB90CE45404672439D03F50E40E0AC776E90CE454081F7448DF8F40E406F53F2A08FCE4540186D9F9FF3F40E40BD38F1D58ECE45405A09826CFEF40E403427D4788ECE454032FBE18C06F50E40991A57128FCE45409390A3946BF50E4029E1AE038CCE4540E2C6D22C75F50E40A01111A38CCE45408293C89981F50E4023A875768DCE4540	w75780028	75780028	way	yes	\N	\N	\N	7
37	0106000020E6100000010000000103000000010000000600000034D93F4F03F60E407E7CF8E8C3CE454063E1DA3F05F60E40DDB243FCC3CE4540B1DD3D40F7F50E40F5DA6CACC4CE4540FC5C2338E4F50E408A86D6D4C3CE45401EE85729F3F50E40D899E72DC3CE454034D93F4F03F60E407E7CF8E8C3CE4540	w75780046	75780046	way	yes	\N	\N	\N	5
38	0106000020E610000001000000010300000001000000050000001BB2CB01CCF60E40B0D128136DCE45405517F032C3F60E40224B8B9F6BCE45408C5940B2CAF60E40B1D760866BCE45400BB8E7F9D3F60E4039590F046DCE45401BB2CB01CCF60E40B0D128136DCE4540	w75780054	75780054	way	yes	\N	\N	\N	\N
39	0106000020E610000001000000010300000001000000080000007DCEDDAE97F60E40A8CA5246B7CE4540F129A50CC1F60E40A1BF2BDDB8CE454003475DC6A8F60E40C57B69E5B9CE4540C2CA57B89BF60E4083723678BACE454086EBAC7191F60E406BBA9EE8BACE45404078A3456CF60E40B95D1E21B9CE4540D0679B768CF60E400D90C3BBB7CE45407DCEDDAE97F60E40A8CA5246B7CE4540	w75780069	75780069	way	yes	\N	\N	\N	9
40	0106000020E6100000010000000103000000010000000500000000242E5B46F50E4087F656C96CCE4540756506E055F50E40E6FE8FB86CCE4540C81BAA7356F50E4098BD6C3B6DCE4540C36169E047F50E40BC372B476DCE454000242E5B46F50E4087F656C96CCE4540	w75780082	75780082	way	yes	\N	\N	\N	10
41	0106000020E61000000100000001030000000100000010000000866753BF1CF70E40FF452B52BCCE4540ADC9AE0F46F70E40FE3FF3DEBDCE4540AE06729A4FF70E403F8BA548BECE454031ABC14538F70E40FD0BA947BFCE454094E7B0B101F70E406D5FF6A1C1CE454012781673C6F60E40A857CA32C4CE454043869F49ACF60E40907758F2C2CE4540828B153598F60E4038328FFCC1CE4540CED83CB3C9F60E40E58123DCBFCE454057CB42E0EDF60E406D31E47DC1CE45407C478D0931F70E4027A5FB94BECE45407F8A3E7A1EF70E40C35554B3BDCE45404A6BC2AC06F70E40FE5360B7BECE454076F9D687F5F60E40F23515F3BDCE4540335AFDC7F8F60E401C87B0D0BDCE4540866753BF1CF70E40FF452B52BCCE4540	w75780086	75780086	way	yes	\N	\N	\N	9
42	0106000020E61000000100000001030000000100000005000000758F6CAE9AF70E40D3E2E71AC1CE4540BC1F5CA6CBF70E40CC33E5F9C2CE45407F40B15FC1F70E40B47B4D6AC3CE4540F1738DE090F70E40D36C1E87C1CE4540758F6CAE9AF70E40D3E2E71AC1CE4540	w75780104	75780104	way	yes	\N	\N	\N	1
43	0106000020E6100000010000000103000000010000000C000000764309E9DFF40E40CB3AD2CF8ACE4540F85BF1C3F7F40E403C9A8F108ACE454062235A3C06F50E40C092509F89CE4540FF8FB86C19F50E40EF5EA40689CE454008AD872F13F50E40379BD88D88CE4540752B3A483EF50E406DE2E47E87CE4540FF03519C48F50E402CC5443987CE45407FA2B2614DF50E4002D0CDA387CE454025D52DF136F50E40373FB44588CE454056574FF74BF50E4031067BB889CE4540CF108E59F6F40E40A6BADB508CCE4540764309E9DFF40E40CB3AD2CF8ACE4540	w75780118	75780118	way	yes	\N	\N	\N	6
44	0106000020E610000001000000010300000001000000080000009E59B7E633F50E403851A62C9ECE4540DEB5DF3543F50E40D88AEC399FCE4540A36DA1D057F50E40AE0507C5A0CE454043FDD3B25AF50E40B4661A03A1CE45409725F03D12F50E400040A951A3CE45402B01E77BFCF40E40CB187A1FA2CE454073034F6BE4F40E407E816ACDA0CE45409E59B7E633F50E403851A62C9ECE4540	w75780125	75780125	way	yes	\N	\N	\N	8
45	0106000020E610000001000000010300000001000000050000005D5320B3B3F80E40841843948ACE4540D2ACC7D864F80E400154CC9C89CE4540A97E4A3A6FF80E40DE8321BC87CE454010977730BDF80E40E4CA8FAE88CE45405D5320B3B3F80E40841843948ACE4540	w75780133	75780133	way	yes	\N	\N	\N	5
46	0106000020E610000001000000010300000001000000060000002789809E61F50E40615111A793CE4540A741D13C80F50E40663623DE95CE45407C5F01F15FF50E4042FEE3CE96CE454077A5C05D51F50E40FBC7E7BA95CE4540D8F8A7AF42F50E408A123EA594CE45402789809E61F50E40615111A793CE4540	w75780136	75780136	way	yes	\N	\N	\N	7
47	0106000020E61000000100000001030000000100000005000000583F918202FA0E4018A4CFFD8BCE45401583D1F6F9F90E405EC026C68DCE45408F899466F3F80E4042B3EBDE8ACE4540665B17C8FDF80E40841E7B0789CE4540583F918202FA0E4018A4CFFD8BCE4540	w75780165	75780165	way	yes	\N	\N	\N	8
48	0106000020E6100000010000000103000000010000000D0000008046E9D2BFF40E406CFF14D8ADCE4540AA5F8EC305F50E40CCCB063EABCE4540C9586DFE5FF50E40410466CFAFCE454055E0BFD42AF50E40AB52C433B2CE454048B2FD1AFFF40E405227A089B0CE454019AA622AFDF40E4011381268B0CE4540A922CB38FCF40E40D54D733CB0CE4540A36593B2FBF40E4076172829B0CE45405B295F2BFCF40E409A63D410B0CE4540F97BCE82F5F40E401180C9D7AFCE45408457DCC9F1F40E40C4E28112B0CE45401850B9D3E7F40E40655012B7AFCE45408046E9D2BFF40E406CFF14D8ADCE4540	w75780202	75780202	way	yes	\N	\N	\N	8
49	0106000020E610000001000000010300000001000000050000003851A62C9EF50E40800063C790CE4540F1513530A8F50E405C6CFF6F91CE4540B5728AE99DF50E408042E2C391CE4540AE788FD893F50E40A4D6451B91CE45403851A62C9EF50E40800063C790CE4540	w75780204	75780204	way	yes	\N	\N	\N	5
50	0106000020E61000000100000001030000000100000024000000B545E39A4CF60E40684B0CB89DCE4540F9049A1947F60E40EAB35E679ECE454056BB26A435F60E400DB21B6CA0CE45401F7CCD1720F60E40BFF4F6E7A2CE45403E6D9E341EF60E401221640FA3CE454039D0436D1BF60E406B52C02CA3CE45402F76B11F18F60E405F48E240A3CE4540BA51BF6614F60E405943F34AA3CE4540207FC40A12F60E405943F34AA3CE454087ACC9AE0FF60E407185C146A3CE4540A69D9ACB0DF60E40778AB03CA3CE4540C48E6BE80BF60E40124F7633A3CE45404E4A9C700AF60E4030963325A3CE4540DDC2047F09F60E40359B221BA3CE45406D3B6D8D08F60E4053E2DF0CA3CE4540FCB3D59B07F60E4071299DFEA2CE454070445266DEF50E401F65C405A0CE454041FFF3EAD2F50E402051572D9FCE45402A45E169E8F50E400E2E1D739ECE45404716D5C7E8F50E40DFF137EB9DCE4540F47C1700F4F50E405CE509849DCE4540BB54B65906F60E40BBED42739DCE4540251C1FD214F60E405C2DC1F39CCE45405F645D3700F60E40ECEDE0719BCE4540D042A78C24F60E4041E43E8397CE4540AB5AD2510EF60E40A795422097CE4540F5108DEE20F60E4084D9041896CE45406FD2D96E27F60E40190FA5AC95CE4540EBD3E06C29F60E402A04CD4296CE4540A954E46B2AF60E406CF35A6496CE454019DC7B5D2BF60E40C524B78196CE454090204BD52CF60E40061445A396CE4540712F7AB82EF60E404E08C2BA96CE4540D5AD43DA6BF60E4010CAFB389ACE45401273FF475CF60E40C82B6BF69BCE4540B545E39A4CF60E40684B0CB89DCE4540	w75780215	75780215	way	yes	\N	\N	\N	15
51	0106000020E6100000010000000103000000010000000A000000508248D0A9F50E40956D9681B9CE4540E8DDB3098BF50E40C4BDE8E1BACE45405DA8FC6B79F50E403C229518BACE45405948652F80F50E408F3A9567B9CE45408CED5AE784F50E40EFB897EAB8CE4540FC54151A88F50E401FB3FD75B8CE45404DCBFE2F8DF50E404832AB77B8CE4540FC71FBE593F50E4072B15879B8CE4540DB5D5617A6F50E4030044A54B9CE4540508248D0A9F50E40956D9681B9CE4540	w75780280	75780280	way	yes	\N	\N	\N	8
52	0106000020E610000001000000010300000001000000160000002CAFA6FCB5F60E404106973380CE454063658FABECF60E402B40CA3E7ECE454006E6D7C523F70E4091F7054F7CCE454010406A1327F70E40BB48A12C7CCE45404DE83FB50BF70E402DAE96E079CE454095D2D80352F70E40A52CE86278CE4540BE1D3C6E53F70E4081E03B7B78CE4540AAA6DA5D56F70E40FEB968C878CE45408412C19371F70E40DF9A85877ACE4540EB2AEE89BFF70E4018A18E7D7FCE45405D7BB0D69AF70E4082C1DABD81CE454061BE614788F70E40595CD20781CE454031B3CF6394F70E404134A95780CE4540DD4BD0155BF70E405B26C3F17CCE4540068F256200F70E40FA111A1C80CE45405CA56032FAF60E407D38EDCE7FCE4540CB958B42DCF60E404DF6CFD380CE45406108EF61E5F60E40CA2B216981CE45405A48C0E8F2F60E40EEED96E480CE4540411C357051F70E409EF6EF5586CE45405FB35C363AF70E40143BBFCD87CE45402CAFA6FCB5F60E404106973380CE4540	w75780332	75780332	way	yes	\N	\N	\N	15
53	0106000020E61000000100000001030000000100000005000000C98A86318EF60E4066A032FE7DCE4540B5A4A31CCCF60E40919BE1067CCE454063658FABECF60E402B40CA3E7ECE45402CAFA6FCB5F60E404106973380CE4540C98A86318EF60E4066A032FE7DCE4540	w75780345	75780345	way	yes	\N	\N	\N	11
54	0106000020E6100000010000000103000000010000000B00000002791B4064F60E404778D6C974CE45408D1A5DEF48F60E40A72A23E472CE45400BB3D0CE69F60E40E35C797F72CE4540F312AD2699F60E40BA2583ED71CE45404B83914DA8F60E40C0FC5FBF71CE4540A2D68FA8ABF60E407E69F6E571CE45403849F3C7B4F60E40FBFA6BC372CE45406E4B89C9C0F60E40544035B973CE4540191B5F20ADF60E4048C08D3974CE45407391312DA0F60E406CF8CC4873CE454002791B4064F60E404778D6C974CE4540	w75780351	75780351	way	yes	\N	\N	\N	10
55	0106000020E6100000010000000103000000010000000E000000242E5B4645F70E4054E81780A1CE4540A7EF90BD39F70E405F62878CA2CE45405AD93EE42DF70E407143424AA2CE45409D7818A42AF70E4089E1348EA2CE45405062C6CA1EF70E409BC2EF4BA2CE45408F4A56EAFEF60E40462EEEF5A4CE45403B89AD45B0F60E40D664D707A3CE4540B32A1D07B9F60E40DD836B49A2CE454005C1E3DBBBF60E40A199CC1DA2CE45407AE5D594BFF60E40B3A899FFA1CE454060915F3FC4F60E403C3080F0A1CE4540933655F7C8F60E40A16BBAF9A1CE4540835957BBDCF60E40FC8EE1B19FCE4540242E5B4645F70E4054E81780A1CE4540	w75780359	75780359	way	yes	\N	\N	\N	15
56	0106000020E61000000100000001030000000100000008000000D0F302475DF60E40BFF1B56796CE45405D667D6F78F60E40D71F178B95CE4540B6F63E5585F60E40D733846396CE45402C3B0ECD86F60E40FADB549396CE4540EBDBEE8A85F60E4047BB1B5597CE45401C2444F982F60E40DCD6169E97CE45404FAC53E57BF60E403BF3BC6598CE4540D0F302475DF60E40BFF1B56796CE4540	w75780403	75780403	way	yes	\N	\N	\N	10
57	0106000020E6100000010000000103000000010000000E000000BE1D3C6E53F70E4081E03B7B78CE454021D6D127A8F70E406A6226F675CE4540EF6D9FFAACF70E40A6A8E96976CE454085E0021AB6F70E405EC8D92A77CE4540D1F35D00D0F70E4033FB3C4679CE454001738813F3F70E40A9818BBA7BCE45400F6A7528F9F70E40A90BC2267CCE4540CB8DD8DDF2F70E40CCE1A47A7CCE45406646E460DBF70E401346B3B27DCE4540E10A28D4D3F70E401F08DA2E7ECE4540EB2AEE89BFF70E4018A18E7D7FCE45408412C19371F70E40DF9A85877ACE4540AAA6DA5D56F70E40FEB968C878CE4540BE1D3C6E53F70E4081E03B7B78CE4540	w75780430	75780430	way	yes	\N	\N	\N	10
58	0106000020E610000001000000010300000001000000050000002CBC26FFEEF80E40D9846A3986CE4540DC3818A023F80E40DAA447F883CE4540CC78003043F80E40FB8D1B237ECE45401CFC0E8F0EF90E40FA6D3E6480CE45402CBC26FFEEF80E40D9846A3986CE4540	w75780432	75780432	way	yes	\N	\N	\N	1
59	0106000020E6100000010000000103000000010000000A0000007AFD497CEEF40E40E708CF3A99CE4540D4731C89E1F40E40F4FE3F4E98CE4540B91CAF40F4F40E4018C1B5C997CE45401FDB32E02CF50E407ED4152296CE4540149E865E35F50E401E8425C396CE4540A213F87942F50E40350873BB97CE45405EE0A8CB18F50E40D56FCBEC98CE4540F51840530AF50E40D5F9015999CE4540176AA8AC01F50E40F38876BA98CE45407AFD497CEEF40E40E708CF3A99CE4540	w75780435	75780435	way	yes	\N	\N	\N	8
60	0106000020E61000000100000001030000000100000005000000367DD179E8F60E404183A856BACE4540866753BF1CF70E40FF452B52BCCE454047EE44A401F70E4016F88A6EBDCE454005FBAF73D3F60E400B0E8A41BBCE4540367DD179E8F60E404183A856BACE4540	w75780452	75780452	way	yes	\N	\N	\N	8
61	0106000020E61000000100000001030000000100000005000000E6DC370884F70E406BBF10CD97CE454029AECF413CF70E40EE5BAD1397CE454095B5F23746F70E40AE44454195CE4540E25CC30C8DF70E40AD2AA0F595CE4540E6DC370884F70E406BBF10CD97CE4540	w75780454	75780454	way	yes	\N	\N	\N	5
62	0106000020E61000000100000001030000000100000008000000F03E7DBA70F60E40F6C9F6C6B5CE4540FE67284932F60E402C3F15DCB4CE45409A97C3EE3BF60E40FD1CD59FB3CE454038B066AE1DF60E40B0993226B3CE45401F99B3E32BF60E40589C20A0B1CE45409F71E14048F60E405826570CB2CE45403575C35B8CF60E4087EC7200B3CE4540F03E7DBA70F60E40F6C9F6C6B5CE4540	w75780459	75780459	way	yes	\N	\N	\N	11
63	0106000020E6100000010000000103000000010000000C00000008115FDCFCF50E402726B90DB4CE454063337678BEF50E4063A0C618B3CE45404202EBDDC4F50E4016EF117BB2CE45406ECACB50CBF50E40347E86DCB1CE4540F30588DDD2F50E40B71A2323B1CE4540F6622827DAF50E404CF49E6FB0CE45402AB9799917F60E4099017855B1CE45401D0247020DF60E40F274536FB2CE454003571E49EEF50E4087AAF303B2CE45401591BCCEE1F50E405796E82CB3CE45407D35519500F60E409E149CB0B3CE454008115FDCFCF50E402726B90DB4CE4540	w75780463	75780463	way	yes	\N	\N	\N	7
64	0106000020E6100000010000000103000000010000000A000000232B645353F70E404E548039C4CE45401BF4A5B73FF70E40B9A81611C5CE454037F4609C09F70E4029FC636BC7CE4540BA7BCA7BE6F60E40535337BCC5CE454012781673C6F60E40A857CA32C4CE454094E7B0B101F70E406D5FF6A1C1CE454013BDE71B2CF70E409C95A3B6C3CE45401E543DF438F70E40840B1E4BC4CE454040DF71E547F70E40CC1940AEC3CE4540232B645353F70E404E548039C4CE4540	w75780464	75780464	way	yes	\N	\N	\N	10
65	0106000020E61000000100000001030000000100000009000000D9CEF753E3F50E40C3A68416C8CE4540445F8B27CCF50E40F9ED9007C7CE4540DF1797AAB4F50E4047776BF4C5CE4540FC5C2338E4F50E408A86D6D4C3CE4540B1DD3D40F7F50E40F5DA6CACC4CE454063E1DA3F05F60E40DDB243FCC3CE4540D162844B22F60E406B0BCF4BC5CE4540AE60C037F2F50E40C4C02962C7CE4540D9CEF753E3F50E40C3A68416C8CE4540	w75780475	75780475	way	yes	\N	\N	\N	12
66	0106000020E6100000010000000103000000010000000F00000008115FDCFCF50E402726B90DB4CE45404CD0155BF7F50E4056629E95B4CE45406067542AF2F50E4009693288B4CE4540BADD2637E5F50E405CD71EACB5CE4540D68B46E3F5F50E40E4727275B6CE4540C1806FE4CBF50E4090CA0347B8CE454052C2024EA5F50E407F37386CB6CE4540B9EF07F2A2F50E40C1CAA145B6CE4540FB6E04F3A1F50E40025E0B1FB6CE4540FB6E04F3A1F50E40C7736CF3B5CE45401EFD2FD7A2F50E408B89CDC7B5CE45400DE36E10ADF50E4062C8A0C9B4CE45409C78BDEAB7F50E402DCF83BBB3CE454063337678BEF50E4063A0C618B3CE454008115FDCFCF50E402726B90DB4CE4540	w75780486	75780486	way	yes	\N	\N	\N	8
67	0106000020E61000000100000001030000000100000007000000B5728AE99DF50E403E84A7469ECE45400795B88E71F50E404FBB4ED99FCE4540A36DA1D057F50E40AE0507C5A0CE4540DEB5DF3543F50E40D88AEC399FCE4540AD3BCC4D8AF50E40A4F32BE79CCE4540E45D3F0E94F50E40265C7E969DCE4540B5728AE99DF50E403E84A7469ECE4540	w75780510	75780510	way	yes	\N	\N	\N	7
68	0106000020E61000000100000001030000000100000008000000F168E388B5F80E40E732DA4F6BCE4540B65A71BBE1F80E40C8E5E4EA6CCE454046D3D9C9E0F80E403F5EFEF96CCE45403A1F9E25C8F80E403925C56C6ECE4540479C0425BBF80E403206312B6FCE4540E083D72E6DF80E40DA3C693C6CCE454016FDFC529AF80E408786C5A86BCE4540F168E388B5F80E40E732DA4F6BCE4540	w75780518	75780518	way	yes	\N	\N	\N	10
69	0106000020E61000000100000001030000000100000005000000426ED0A80AF70E40E6A9B3FFA6CE4540FD378A07EFF60E407AD3E3ADA9CE45401FF87365ABF60E4045ACB47BA8CE4540B1074955C9F60E40FF1FCC92A5CE4540426ED0A80AF70E40E6A9B3FFA6CE4540	w75780524	75780524	way	yes	\N	\N	\N	10
70	0106000020E6100000010000000103000000010000000C000000CFA91A738DF50E408E3F51D9B0CE45407A5C0AFE6DF50E401DD25E33AFCE454031A64F615BF50E40594C6C3EAECE454077A5C05D51F50E40BFCF5DB7ADCE4540BBBB29406FF50E40C564BB8CACCE45403AE004F060F50E400740DCD5ABCE454066C5CB2E73F50E40739AAA20ABCE4540ED97F49C99F50E4024534F30ADCE45403E2BC47EAAF50E409BDFD517AECE454045EBF2F79CF50E40833BAB60AFCE4540C9E9EBF99AF50E403BA35291AFCE4540CFA91A738DF50E408E3F51D9B0CE4540	w75780531	75780531	way	yes	\N	\N	\N	9
71	0106000020E6100000010000000103000000010000000B00000008605EDB36F70E40B1636D9DC9CE45400217BF8465F70E4058AE1287C7CE4540C7F07D16F0F70E40259CCC2ECECE45404CDD955D30F80E40A1DF5229D1CE4540EC3A0AC677F80E40A2EBC20FCECE454073B389DD88F80E4018CE35CCD0CE4540AF92342493F80E40DC398375D2CE45409DAA31D758F80E4099B44E01D5CE4540AB2A8FC93DF80E4015A2E826D6CE45405155FC3ACBF70E40E91B87B0D0CE454008605EDB36F70E40B1636D9DC9CE4540	w75780542	75780542	way	yes	\N	\N	\N	9
72	0106000020E610000001000000010300000001000000050000008A4AD9D8DBFC0E408974E4EDADCE45404F690E5A59FC0E40FFCC203EB0CE4540513239B533FC0E40A837A3E6ABCE45408B130434B6FC0E4032DF6696A9CE45408A4AD9D8DBFC0E408974E4EDADCE4540	w75780543	75780543	way	yes	\N	\N	\N	16
73	0106000020E610000001000000010300000001000000080000009D2E8B89CDF70E403A99130F83CE4540EA44DD62D9F70E407BE4C57883CE45407640C868D3F70E400452071E84CE4540248D1BC8C4F70E403E6480FA85CE45406A6CAF05BDF70E40F008B83187CE454031B3CF6394F70E40444FCAA486CE45409A5A5B1DA5F70E40561C188A85CE45409D2E8B89CDF70E403A99130F83CE4540	w75780567	75780567	way	yes	\N	\N	\N	7
74	0106000020E610000001000000010300000001000000050000000F327F3B3FFB0E409C89E942ACCE45407B39A23149FB0E402C369CE8A9CE45405B45DA2159FB0E4097A4D70BAACE4540EF3DB72B4FFB0E409CB7FB66ACCE45400F327F3B3FFB0E409C89E942ACCE4540	w75780601	75780601	way	yes	\N	\N	\N	25
75	0106000020E6100000010000000103000000010000000B00000027FCADF8E1FB0E40952E5805C5CE4540F72AE8AC05FC0E40E36F7B82C4CE45402BF0BA2308FC0E40F464A318C5CE454078B471C45AFC0E405A023ADDC3CE4540EA78CC4065FC0E4023B5F578C6CE454027AA12C028FC0E402F2F6585C7CE454040DEAB5626FC0E402FD3403DC7CE4540C042418413FC0E406AEBF18CC7CE454013F9E41714FC0E40644227DFC7CE4540F250CA5AF9FB0E4088461C57C8CE454027FCADF8E1FB0E40952E5805C5CE4540	w75780657	75780657	way	yes	\N	\N	\N	12
76	0106000020E6100000010000000103000000010000000800000030B374AA21F60E408E00135DBCCE45408F6FEF1AF4F50E40AD95BF31BACE4540C1806FE4CBF50E4090CA0347B8CE4540D68B46E3F5F50E40E4727275B6CE4540FE4A427D26F60E400D0055DCB8CE4540679B1BD313F60E409BA0979BB9CE4540F54A598638F60E40D07F0F5EBBCE454030B374AA21F60E408E00135DBCCE4540	w75780668	75780668	way	yes	\N	\N	\N	8
77	0106000020E61000000100000001030000000100000005000000F72AE8AC05FC0E40E36F7B82C4CE45402CDBE27558FC0E4031CB434BC3CE454078B471C45AFC0E405A023ADDC3CE45402BF0BA2308FC0E40F464A318C5CE4540F72AE8AC05FC0E40E36F7B82C4CE4540	w75780673	75780673	way	yes	\N	\N	\N	11
78	0106000020E61000000100000001030000000100000013000000FA5D7DE13AFB0E401DB8B9E7AFCE4540037B4CA434FB0E4065B26E72AECE45406E45AC0F35FB0E400C811255AECE4540075273034FFB0E4095DAE621AECE454081F6D9B749FB0E40544DB5BBACCE4540E3FA1CC473FB0E40C636A968ACCE45403491E39876FB0E402B72E371ACCE4540FD6B79E57AFB0E40CB97BCA6ACCE45402257451383FB0E403C61D394AECE45403D0565BF93FB0E40A773EA6FAECE45407C07E4B78DFB0E407E288705ADCE4540F60A0BEE07FC0E408AF0E5F4ABCE4540B4A8F4B814FC0E40D6AFCFF7AECE45406B2FFDA60BFC0E40CAA5F10BAFCE4540E085ADD9CAFB0E40CA5D3A9CAFCE4540357C0BEBC6FB0E40D653ABAFAECE45404CDF6B088EFB0E40A054562EAFCE4540264344204DFB0E4035CC75BFAFCE4540FA5D7DE13AFB0E401DB8B9E7AFCE4540	w75780679	75780679	way	yes	\N	\N	\N	\N
79	0106000020E61000000100000001030000000100000009000000FCC8AD49B7F50E40D9CB5B1A64CE4540E1911DC0C7F50E4038D4940964CE4540B863A021D2F50E40A919ADFE63CE4540220E23CED4F50E406724E76965CE45407EE19524CFF50E406724E76965CE4540043D2F70D4F50E408FB1C9D067CE4540D19739B8CFF50E40A1EEA8D667CE4540ECCEC941BFF50E40AD2699E667CE4540FCC8AD49B7F50E40D9CB5B1A64CE4540	w75780746	75780746	way	yes	\N	\N	\N	4
80	0106000020E610000001000000010300000001000000070000007093F6ABA5F50E40EDDA3928BCCE4540F4AED579AFF50E400593D1B7BBCE45401E37FC6EBAF50E408ED20039BCCE4540A8120AB6B6F50E40C3B7B06EBCCE45404765790DB0F50E40C35B8C26BCCE4540A9F523EAAAF50E4076BE4461BCCE45407093F6ABA5F50E40EDDA3928BCCE4540	w75780754	75780754	way	yes	\N	\N	\N	\N
81	0106000020E610000001000000010300000001000000050000002B97D75B14F70E40B1DEA815A6CE4540470B2B700DF70E404B89C9C0A6CE454041310D1E01F70E40C9AAAD7DA6CE45406DF9ED9007F70E40DB0132CFA5CE45402B97D75B14F70E40B1DEA815A6CE4540	w75780758	75780758	way	yes	\N	\N	\N	8
82	0106000020E610000001000000010300000001000000090000001F4F26C9CEF60E404B61399DBFCE4540CED83CB3C9F60E40E58123DCBFCE4540828B153598F60E4038328FFCC1CE454019C4ACBC89F60E404A89134EC1CE45408A11781673F60E40EB10493EC0CE4540A2B9A9DC9FF60E40EC8C4A45BECE4540688E5143C0F60E40B6CF74C0BFCE454034E66498C9F60E4033C34659BFCE45401F4F26C9CEF60E404B61399DBFCE4540	w75780778	75780778	way	yes	\N	\N	\N	9
83	0106000020E61000000100000001030000000100000007000000C3CC881C6CFB0E4027F56569A7CE454009E9DFE46DFB0E40ECC20FCEA7CE4540E6B1666490FB0E405DAC037BA7CE4540CB7AD6DAA0FB0E40799F9916ABCE4540DD20FF7167FB0E403D9B559FABCE4540B13B383355FB0E408759C3A0A7CE4540C3CC881C6CFB0E4027F56569A7CE4540	w75780804	75780804	way	yes	\N	\N	\N	19
84	0106000020E610000001000000010300000001000000050000008DBB9C6DC9F50E402773E26190CE45407E8AE3C0ABF50E408D2A1E728ECE4540FE0868C7B2F50E40DBC765378ECE4540547655FBCFF50E405DCE5B2B90CE45408DBB9C6DC9F50E402773E26190CE4540	w75780834	75780834	way	yes	\N	\N	\N	\N
85	0106000020E61000000100000001030000000100000011000000DAD3C4F132F90E4046F01A4F5FCE4540348463963DF90E403F3BE0BA62CE45404A1E99582AF90E40396403E962CE454046A11B5025F90E407554DA8761CE45400D1AFA27B8F80E4098B4F34762CE4540E28EDC3FBBF80E4003379C4363CE4540E62B3707BEF80E40AA05402663CE4540AA69728CBFF80E407A0BDA9A63CE45406D6AEA86B7F80E407406EBA463CE45403F9F1221BFF80E400173E3CC65CE4540CA4054D0A3F80E409660CCF165CE4540CC63288293F80E40049F307260CE454088FB2367BCF80E407083352960CE4540D8ABD914D9F80E40641D33F55FCE454051DEC7D11CF90E4040193E7D5FCE4540559808652BF90E403AE63C635FCE4540DAD3C4F132F90E4046F01A4F5FCE4540	w75780853	75780853	way	yes	\N	\N	\N	9
86	0106000020E6100000010000000103000000010000000B00000046949B4DECF60E40AE934440CFCE454010CCD1E3F7F60E4073C34A60CECE454021ACC612D6F60E40CDCCCCCCCCCE4540EEAF1EF7ADF60E407E294D94CECE4540E318C91EA1F60E401A36CAFACDCE45408302A557B9F60E40974341DFCCCE4540D1C952EBFDF60E40F885FCD8C9CE4540B8CF85EC17F70E4039E51B1BCBCE454023D4B1EF2FF70E4009D11044CCCE45404371C79BFCF60E409C700A86CECE454046949B4DECF60E40AE934440CFCE4540	w75780870	75780870	way	yes	\N	\N	\N	10
87	0106000020E6100000010000000103000000010000000B0000003AB2F2CB60FC0E4089F5A166A3CE4540196481655BFC0E40E1687D80A4CE4540E57CB1F7E2FB0E4011018750A5CE45402FF99FFCDDFB0E4082D60D25A4CE454049B9A063ACFB0E407D19D69EA3CE454098F2C6EEA7FB0E4041CDDAB7A4CE4540CB97BCA6ACFB0E4023861DC6A4CE4540F962940CA5FB0E400A6C297BA6CE45401D6041F56AFB0E40C3BF63D3A5CE4540951E97827FFB0E401FA74302A1CE45403AB2F2CB60FC0E4089F5A166A3CE4540	w75780887	75780887	way	yes	\N	\N	\N	6
88	0106000020E610000001000000010300000001000000060000007AED88F9A8F50E409AB33EE598CE454059654BFB8BF50E4034E895FC99CE4540BD18CA8976F50E40CAADA47098CE45407C5F01F15FF50E4042FEE3CE96CE4540A741D13C80F50E40663623DE95CE45407AED88F9A8F50E409AB33EE598CE4540	w75780895	75780895	way	yes	\N	\N	\N	7
89	0106000020E6100000010000000103000000010000000B00000079D5B95807F60E4002EDB36F93CE4540A18CA7D4DBF50E4072FE81CD94CE4540F988F3CBBBF50E40144438C192CE4540F1513530A8F50E405C6CFF6F91CE45408DBB9C6DC9F50E402773E26190CE4540547655FBCFF50E405DCE5B2B90CE4540B477A11408F60E4088F71C588ECE4540CE05E4011BF60E40E69DF98B8FCE45408CC0B39833F60E40A4D6451B91CE45402B9F8AC0FDF50E40C145DDBD92CE454079D5B95807F60E4002EDB36F93CE4540	w75780916	75780916	way	yes	\N	\N	\N	10
90	0106000020E6100000010000000103000000010000000A00000016516E36B1FB0E40A85489B2B7CE4540F945AE4099FB0E40B4BA8BE6B7CE454038F17AD56FFB0E40AE11C138B8CE45401C237E6A61FB0E40EB4F87BAB4CE4540FD14C78157FB0E40DF45A9CEB4CE45408910B28751FB0E4098B38872B3CE454060E234E95BFB0E40A4BD665EB3CE4540264344204DFB0E4035CC75BFAFCE45404CDF6B088EFB0E40A054562EAFCE454016516E36B1FB0E40A85489B2B7CE4540	w75780941	75780941	way	yes	\N	\N	\N	16
91	0106000020E61000000100000001030000000100000010000000012F336C94F50E402D3421F7BECE454036D71F178BF50E4092F9916CBFCE4540120C31A880F50E406FF59CF4BECE4540928DACA179F50E407A89B14CBFCE45404C8E3BA583F50E409E8DA6C4BFCE45403D409C2C5AF50E40678819D0C1CE4540D57B2AA73DF50E40D92F8E80C0CE454038A3416557F50E40CF8D44C3BDCE45405DA8FC6B79F50E403C229518BACE4540E8DDB3098BF50E40C4BDE8E1BACE45407093F6ABA5F50E40EDDA3928BCCE454023BA675DA3F50E40460C9645BCCE4540A67B9DD497F50E40997A8269BDCE45400E034CCFAAF50E40AB4198DBBDCE4540FB6E04F3A1F50E409389004CBECE4540012F336C94F50E402D3421F7BECE4540	w75780952	75780952	way	yes	\N	\N	\N	13
92	0106000020E610000001000000010300000001000000070000006DF310D77BFB0E402DBE5763BFCE45405C829DAC62FB0E4031C2CA57B8CE454038F17AD56FFB0E40AE11C138B8CE4540F945AE4099FB0E40B4BA8BE6B7CE45407FBE2D58AAFB0E40F39771AEBCCE45407B3EB95CB3FB0E408C6A6C0ABFCE45406DF310D77BFB0E402DBE5763BFCE4540	w75781060	75781060	way	yes	\N	\N	\N	9
93	0106000020E61000000100000001030000000100000006000000FE0868C7B2F50E40DBC765378ECE4540A646E867EAF50E40836E2F698CCE4540763B5684F6F50E40A0C959338DCE4540B477A11408F60E4088F71C588ECE4540547655FBCFF50E405DCE5B2B90CE4540FE0868C7B2F50E40DBC765378ECE4540	w75781077	75781077	way	yes	\N	\N	\N	9
94	0106000020E610000001000000010300000001000000090000002A5A14D10AF70E40B3C00DE7D0CE454080338C16FBF60E4013E3EB21D0CE45405E1FE7470DF70E40A2896654CFCE45404371C79BFCF60E409C700A86CECE454023D4B1EF2FF70E4009D11044CCCE45404B1C1E673FF70E40853474FDCCCE45405930F14751F70E40314A86D2CDCE454009466F021DF70E40CBEE6E0AD0CE45402A5A14D10AF70E40B3C00DE7D0CE4540	w75781085	75781085	way	yes	\N	\N	\N	10
95	0106000020E6100000010000000103000000010000000D000000D5AD43DA6BF60E4010CAFB389ACE4540712F7AB82EF60E404E08C2BA96CE454090204BD52CF60E40061445A396CE454019DC7B5D2BF60E40C524B78196CE4540A954E46B2AF60E406CF35A6496CE4540EBD3E06C29F60E402A04CD4296CE45406FD2D96E27F60E40190FA5AC95CE4540C948AC7B1AF60E403D47E4BB94CE45407949528836F60E40433866D993CE4540D0F302475DF60E40BFF1B56796CE45404FAC53E57BF60E403BF3BC6598CE454042D5438F73F60E40403A2B5899CE4540D5AD43DA6BF60E4010CAFB389ACE4540	w75781108	75781108	way	yes	\N	\N	\N	8
96	0106000020E61000000100000001030000000100000006000000EF6D9FFAACF70E40A6A8E96976CE4540ABCBCE47BEF70E408EDCE40176CE45406DE92C0EC2F70E40769A160676CE454093D4F83BCAF70E40CF83BBB376CE454085E0021AB6F70E405EC8D92A77CE4540EF6D9FFAACF70E40A6A8E96976CE4540	w75781119	75781119	way	yes	\N	\N	\N	8
97	0106000020E6100000010000000103000000010000000B00000065A5EE6F75F50E40ACB992D38DCE45408293C89981F50E4023A875768DCE4540BD00FBE8D4F50E4083A279008BCE454035A26AAADDF50E40429946938BCE4540A646E867EAF50E40836E2F698CCE4540FE0868C7B2F50E40DBC765378ECE45407E8AE3C0ABF50E408D2A1E728ECE45404628B682A6F50E40AB15B71B8ECE45401B46E63686F50E4087DD770C8FCE454084D382177DF50E404031B2648ECE454065A5EE6F75F50E40ACB992D38DCE4540	w75781134	75781134	way	yes	\N	\N	\N	6
98	0106000020E610000001000000010300000001000000090000005A91E22DA1FC0E40D4A6A091BECE454055D4AAA7A0FC0E403986B652BECE454047448C3276FD0E40F3C583D2BCCE454080E37CFB84FD0E4099EA138ABECE4540DE1099A894FD0E400381295EC0CE4540AA46AF0628FD0E408B1C7D27C1CE45409B0DE83BAEFC0E40AFAAA80BC2CE45409D4DA2B9A9FC0E4026851ED6C0CE45405A91E22DA1FC0E40D4A6A091BECE4540	w75781220	75781220	way	yes	\N	\N	\N	15
99	0106000020E6100000010000000103000000010000000A000000330BFEC8BEF50E40A30227DBC0CE454003006CE5CAF50E400353173AC0CE4540FB6E04F3A1F50E409389004CBECE45400E034CCFAAF50E40AB4198DBBDCE45409B58E02BBAF50E401CA1551CBDCE454021EE450FD7F50E400B98C0ADBBCE45406F5E413FF8F50E40588BF447BDCE45407E8FFAEB15F60E40FE5360B7BECE4540E88B18D1D1F50E4026998BAEC1CE4540330BFEC8BEF50E40A30227DBC0CE4540	w75781249	75781249	way	yes	\N	\N	\N	9
100	0106000020E61000000100000001030000000100000006000000D0F302475DF60E40BFF1B56796CE45407949528836F60E40433866D993CE45404EF8003851F60E405B66C7FC92CE4540FB9B06FB65F60E4079793A5794CE45405D667D6F78F60E40D71F178B95CE4540D0F302475DF60E40BFF1B56796CE4540	w75781269	75781269	way	yes	\N	\N	\N	10
101	0106000020E610000001000000010300000001000000060000005EE0A8CB18F50E40D56FCBEC98CE4540A213F87942F50E40350873BB97CE45408A1C226E4EF50E402F17F19D98CE45401178BBB953F50E40F3E49A0299CE4540850838842AF50E402E11B92A9ACE45405EE0A8CB18F50E40D56FCBEC98CE4540	w75781282	75781282	way	yes	\N	\N	\N	7
102	0106000020E61000000100000001030000000100000006000000628F3F074CF60E40F0468BD8CCCE45408A2E5EE27EF60E40DA249A9BCACE4540E0617F7E84F60E40AA44D95BCACE4540DBE10A838DF60E40E68A9CCFCACE454063CC029255F60E402C8D4E4CCDCE4540628F3F074CF60E40F0468BD8CCCE4540	w75781364	75781364	way	yes	\N	\N	\N	5
103	0106000020E610000001000000010300000001000000060000009E59B7E633F50E403851A62C9ECE4540B51BD8857AF50E400ABFD4CF9BCE4540FFB4AC5681F50E402DC3C9479CCE4540AD3BCC4D8AF50E40A4F32BE79CCE4540DEB5DF3543F50E40D88AEC399FCE45409E59B7E633F50E403851A62C9ECE4540	w75781373	75781373	way	yes	\N	\N	\N	7
104	0106000020E6100000010000000103000000010000000700000061D6D52EB7F50E40D92F8E80C0CE4540AB18F89B9AF50E40B0123D3ABFCE4540012F336C94F50E402D3421F7BECE4540FB6E04F3A1F50E409389004CBECE454003006CE5CAF50E400353173AC0CE4540330BFEC8BEF50E40A30227DBC0CE454061D6D52EB7F50E40D92F8E80C0CE4540	w75781380	75781380	way	yes	\N	\N	\N	7
105	0106000020E61000000100000001030000000100000005000000375BD48272F60E406F2C280CCACE45408A2E5EE27EF60E40DA249A9BCACE4540628F3F074CF60E40F0468BD8CCCE45400FBCB5A73FF60E40864E1949CCCE4540375BD48272F60E406F2C280CCACE4540	w75781396	75781396	way	yes	\N	\N	\N	6
106	0106000020E610000001000000010300000001000000050000003A1F9E25C8F80E403925C56C6ECE454046D3D9C9E0F80E403F5EFEF96CCE4540226294B1EBF80E40E6E4EA6C6DCE454017AE580DD3F80E40FDF26ED16ECE45403A1F9E25C8F80E403925C56C6ECE4540	w75781399	75781399	way	yes	\N	\N	\N	9
107	0106000020E6100000010000000103000000010000000D00000061D6D52EB7F50E40D92F8E80C0CE4540330BFEC8BEF50E40A30227DBC0CE454046D1031F83F50E407216F6B4C3CE454057CEDE196DF50E40A25813B0C2CE45403D409C2C5AF50E40678819D0C1CE45404C8E3BA583F50E409E8DA6C4BFCE454036D71F178BF50E4092F9916CBFCE4540012F336C94F50E402D3421F7BECE4540AB18F89B9AF50E40B0123D3ABFCE4540D6862FB88BF50E404ABD5DE5BFCE4540D6862FB88BF50E4003250516C0CE454063F9A9E0A6F50E40CD0B0B49C1CE454061D6D52EB7F50E40D92F8E80C0CE4540	w75781406	75781406	way	yes	\N	\N	\N	9
108	0106000020E610000001000000010300000001000000070000005C0CD41863F60E40BA3EBD63C2CE4540D162844B22F60E406B0BCF4BC5CE454063E1DA3F05F60E40DDB243FCC3CE454034D93F4F03F60E407E7CF8E8C3CE4540EE8A2A0D46F60E40CDAFE600C1CE4540C31CF3F054F60E40F614EFB6C1CE45405C0CD41863F60E40BA3EBD63C2CE4540	w75781412	75781412	way	yes	\N	\N	\N	9
109	0106000020E61000000100000001030000000100000005000000BC6E5BA505F90E409160AA99B5CE4540B84082E2C7F80E40D926158DB5CE4540BDFDB968C8F80E40C89349B2B3CE45407AEF5EA406F90E40688B10C3B3CE4540BC6E5BA505F90E409160AA99B5CE4540	w75781419	75781419	way	yes	\N	\N	\N	3
110	0106000020E61000000100000001030000000100000006000000E26C848FD2F60E4046CD57C9C7CE45401C5E10919AF60E402794CF3CCACE4540F2D5E99B8FF60E404523449EC9CE45407017AB178DF60E407BC674D7C8CE45408E5C37A5BCF60E403B53E8BCC6CE4540E26C848FD2F60E4046CD57C9C7CE4540	w75781421	75781421	way	yes	\N	\N	\N	8
111	0106000020E61000000100000001030000000100000008000000BB719C2512F60E40DFBB7262B4CE454008115FDCFCF50E402726B90DB4CE45407D35519500F60E409E149CB0B3CE45401D0247020DF60E40F274536FB2CE45402AB9799917F60E4099017855B1CE45401F99B3E32BF60E40589C20A0B1CE454038B066AE1DF60E40B0993226B3CE4540BB719C2512F60E40DFBB7262B4CE4540	w75781431	75781431	way	yes	\N	\N	\N	7
112	0106000020E61000000100000001030000000100000009000000EE43392C68F50E404E9B711AA2CE45405708ABB184F50E406CCEC133A1CE454033EE17FDB2F50E401F09A0BD9FCE45406EADE584BFF50E40C619C39CA0CE4540B169A510C8F50E40964D6F35A1CE454072F096F5ACF50E409561DC0DA2CE45403714E3A194F50E40A17F27D2A2CE4540D3ECCBE37AF50E4023168CA5A3CE4540EE43392C68F50E404E9B711AA2CE4540	w75781444	75781444	way	yes	\N	\N	\N	7
113	0106000020E61000000100000001030000000100000006000000D4298F6E84F50E40A650CC30A4CE45401043064DA6F50E400AB4E0EAA5CE45409B8D959867F50E4092EDD7F8A7CE45404ADAE8F758F50E408DD47B2AA7CE45407FA2B2614DF50E402EE6E786A6CE4540D4298F6E84F50E40A650CC30A4CE4540	w75781453	75781453	way	yes	\N	\N	\N	9
114	0106000020E6100000010000000103000000010000000C000000C5701A4751FC0E40A9ED7085C1CE45409D4DA2B9A9FC0E4026851ED6C0CE45409B0DE83BAEFC0E40AFAAA80BC2CE4540F9A985ED82FC0E4043C6A354C2CE4540B52792F991FC0E40F4D43439C6CE4540B52792F991FC0E40530B804CC6CE45409CB92CCB7CFC0E40066E3887C6CE4540F5F23B4D66FC0E40A08E22C6C6CE4540EA78CC4065FC0E4023B5F578C6CE454078B471C45AFC0E405A023ADDC3CE45402CDBE27558FC0E4031CB434BC3CE4540C5701A4751FC0E40A9ED7085C1CE4540	w75781473	75781473	way	yes	\N	\N	\N	10
115	0106000020E6100000010000000103000000010000000A00000042902859F3F80E40BD6B75DE6BCE45405E5E25C401F90E40E7D6B5076BCE454072B8A008F3F80E40E1197E816ACE4540356A74BD23F90E409A6DB8D969CE4540031F285C34F90E407DCAD69F69CE4540618907944DF90E40700278B06ACE454001FC53AA44F90E4076BFAF366BCE4540F2CA9AFD26F90E402D211FF46CCE45404FBEEA121FF90E40BC653D6B6DCE454042902859F3F80E40BD6B75DE6BCE4540	w75781481	75781481	way	yes	\N	\N	\N	9
116	0106000020E61000000100000001030000000100000008000000FD378A07EFF60E407AD3E3ADA9CE454003BBF5F5D7F60E407885F4CAABCE4540135E279AACF60E408EFDD1DCAFCE4540EF75525F96F60E4011F6926BAFCE4540F4893C49BAF60E40A837A3E6ABCE45408DC8C1B68FF60E405B58DC24ABCE45401FF87365ABF60E4045ACB47BA8CE4540FD378A07EFF60E407AD3E3ADA9CE4540	w75781503	75781503	way	yes	\N	\N	\N	10
117	0106000020E61000000100000001030000000100000007000000EE8A2A0D46F60E40CDAFE600C1CE454034D93F4F03F60E407E7CF8E8C3CE45401EE85729F3F50E40D899E72DC3CE4540E88B18D1D1F50E4026998BAEC1CE45407E8FFAEB15F60E40FE5360B7BECE454048E4164E2DF60E401506C0D3BFCE4540EE8A2A0D46F60E40CDAFE600C1CE4540	w75781508	75781508	way	yes	\N	\N	\N	12
118	0106000020E6100000010000000103000000010000000800000072F096F5ACF50E40E6C3584BA6CE454040FCFCF7E0F50E408F705AF0A2CE4540FDD3B25A05F60E40112F9974A5CE4540BB54B65906F60E40461449AAA5CE454080780206EEF50E40570339CDA7CE45403A3FC571E0F50E40F76A91FEA8CE4540E5F1B4FCC0F50E4075C0BF52A7CE454072F096F5ACF50E40E6C3584BA6CE4540	w75781517	75781517	way	yes	\N	\N	\N	8
119	0106000020E610000001000000010300000001000000060000005708ABB184F50E406CCEC133A1CE45400795B88E71F50E404FBB4ED99FCE4540B5728AE99DF50E403E84A7469ECE4540A458C922A8F50E4067E9AFFC9ECE454033EE17FDB2F50E401F09A0BD9FCE45405708ABB184F50E406CCEC133A1CE4540	w75781553	75781553	way	yes	\N	\N	\N	10
120	0106000020E61000000100000001030000000100000009000000F958B043EBF70E403B1DC87A6ACE454087EB072B04F80E40E7C2482F6ACE4540267B3A0D07F80E40290EFB986ACE4540826B932F0DF80E40B295E1896ACE4540E538019711F80E405EABF35E6BCE45409A45836FF5F70E402E837BAF6BCE4540A91F8AB8EFF70E40ED93ED8D6BCE454070BD5C7AEAF70E40E12DEB596BCE4540F958B043EBF70E403B1DC87A6ACE4540	w75781559	75781559	way	yes	\N	\N	\N	3
121	0106000020E6100000010000000103000000010000000B000000DBE10A838DF60E40E68A9CCFCACE45401C5E10919AF60E402794CF3CCACE4540E26C848FD2F60E4046CD57C9C7CE4540A724462AE7F60E401C9029C4C8CE4540D1C952EBFDF60E40F885FCD8C9CE45408302A557B9F60E40974341DFCCCE4540A1B6B2E9ADF60E4014090154CCCE454079E2DEA1CDF60E406F4095E4CACE4540A670F37CBCF60E4069273916CACE45405DBD2FD39BF60E4092729C80CBCE4540DBE10A838DF60E40E68A9CCFCACE4540	w75781562	75781562	way	yes	\N	\N	\N	8
122	0106000020E6100000010000000103000000010000000A000000DD90EB4BDBF40E403510262081CE454015D33BCBE2F40E406B6B9FE980CE4540BE30992A18F50E401EA67D737FCE4540CD27863F1EF50E404EFC07477FCE4540C2418C214AF50E408E55EF1582CE45400452071E84F50E40B07B86CB85CE454066E2B1FA7EF50E4003A8F3F285CE4540FF03519C48F50E402CC5443987CE4540752B3A483EF50E406DE2E47E87CE4540DD90EB4BDBF40E403510262081CE4540	w75781601	75781601	way	yes	\N	\N	\N	11
123	0106000020E61000000100000001030000000100000006000000DDDE7F7566FC0E40002C3C79A2CE454059E0867368FC0E406C729DEBA0CE4540593739D78BFC0E4060C4E347A1CE45404DBAD2D798FC0E40243031F1A2CE4540F2CC70A884FC0E4012C53FC7A2CE4540DDDE7F7566FC0E40002C3C79A2CE4540	w75781604	75781604	way	yes	\N	\N	\N	7
124	0106000020E61000000100000001030000000100000007000000A5164A26A7F60E4073EC455964CE4540AC3022F6AEF60E400217BF8465CE45408B6B216D88F60E403758930266CE45403B15151681F60E40A92D1AD764CE45407017AB178DF60E405501ADAF64CE4540F9CFE4AC99F60E404496BB8564CE4540A5164A26A7F60E4073EC455964CE4540	w75781611	75781611	way	yes	\N	\N	\N	6
125	0106000020E6100000010000000103000000010000000900000076114B6F24F50E406AFB57569ACE4540850838842AF50E402E11B92A9ACE45401178BBB953F50E40F3E49A0299CE45409013268C66F50E40ED7D4F519ACE4540B51BD8857AF50E400ABFD4CF9BCE45409E59B7E633F50E403851A62C9ECE454010C75FFF1AF50E40637A67599CCE4540E5750EAF35F50E403F1A4E999BCE454076114B6F24F50E406AFB57569ACE4540	w75781614	75781614	way	yes	\N	\N	\N	8
126	0106000020E61000000100000001030000000100000007000000A2B9A9DC9FF60E40EC8C4A45BECE45408A11781673F60E40EB10493EC0CE4540554CA59F70F60E40FD1F1620C0CE4540FF1884036BF60E4027439FD9BFCE4540795160A692F60E40F2632717BECE45405FFDE95097F60E4040016FDCBDCE4540A2B9A9DC9FF60E40EC8C4A45BECE4540	w75781616	75781616	way	yes	\N	\N	\N	8
127	0106000020E61000000100000001030000000100000005000000E2BE1FC88BF60E40B3D6AB23A2CE45402984C42C6AF60E40D73CFD56A1CE45405C46A0B07AF60E40E41E01929FCE4540AF53F6A79EF60E4084CE1033A0CE4540E2BE1FC88BF60E40B3D6AB23A2CE4540	w75781632	75781632	way	yes	\N	\N	\N	4
128	0106000020E61000000100000001030000000100000005000000A9F4B814FCFB0E40157C8967BFCE45403DED951EF2FB0E409E31827CBFCE454045EA8722EEFB0E4039B4C876BECE4540CEC29E76F8FB0E4045BEA662BECE4540A9F4B814FCFB0E40157C8967BFCE4540	w75781642	75781642	way	yes	\N	\N	\N	\N
129	0106000020E61000000100000001030000000100000005000000303B7AB251FC0E40E69BC827BFCE4540C9F08E4248FC0E406F51C13CBFCE4540112DC3C947FC0E40B0E42A16BFCE45402A7E422C51FC0E40A4AC3A06BFCE4540303B7AB251FC0E40E69BC827BFCE4540	w75781666	75781666	way	yes	\N	\N	\N	\N
130	0106000020E610000001000000010300000001000000170000001EA67D737FF50E40B91F4B7A73CE45409013268C66F50E4089F7D2CA73CE4540E509849D62F50E409B4E571C73CE45401F6FA8CE59F50E40904AB1A371CE4540742843554CF50E4002DEB87B6FCE454076BFAF366BF50E40981359106FCE4540034F102B92F50E40211109956ECE4540D03D9061BAF50E40C25087156ECE4540A6EF3504C7F50E40DA6443ED6DCE4540A646E867EAF50E40F21CDB7C6DCE454045A165DD3FF60E4093A4106D6CCE45405D83633B84F60E40FFD0CC936BCE4540E4727275B6F60E4088A06AF46ACE45405D14E236BFF60E4058EEBBD86ACE45405517F032C3F60E40224B8B9F6BCE45401BB2CB01CCF60E40B0D128136DCE4540B4A1AC29DAF60E4014BF73396FCE45402CCC8CC8C1F60E406819F3846FCE4540A27FDD4488F60E40D23F773870CE454077267ED646F60E401A1A4F0471CE454016EB6525F7F50E40EFDC20FF71CE454088C4984FB1F50E406C6E96DC72CE45401EA67D737FF50E40B91F4B7A73CE4540	w75781699	75781699	way	yes	\N	\N	\N	10
131	0106000020E6100000010000000103000000010000000B00000037F4609C09F70E4029FC636BC7CE45401BF4A5B73FF70E40B9A81611C5CE4540A6EC99CA47F70E40FAF3C87AC5CE4540D15AD1E638F70E40ACE0B721C6CE45403A1F436C55F70E40413E3267C7CE45405CAA775D64F70E40884C54CAC6CE4540A4236F6F6DF70E404D1AFE2EC7CE45400217BF8465F70E4058AE1287C7CE454008605EDB36F70E40B1636D9DC9CE4540C0E95DBC1FF70E40DB72897EC8CE454037F4609C09F70E4029FC636BC7CE4540	w75781708	75781708	way	yes	\N	\N	\N	10
132	0106000020E61000000100000001030000000100000006000000AE06729A4FF70E403F8BA548BECE4540758F6CAE9AF70E40D3E2E71AC1CE4540F1738DE090F70E40D36C1E87C1CE454056270C6F7BF70E4097F2107CC2CE454031ABC14538F70E40FD0BA947BFCE4540AE06729A4FF70E403F8BA548BECE4540	w75781733	75781733	way	yes	\N	\N	\N	4
133	0106000020E61000000100000001030000000100000011000000BD00FBE8D4F50E4083A279008BCE45408293C89981F50E4023A875768DCE4540E2C6D22C75F50E40A01111A38CCE4540D56652F98DF50E400639DED38BCE4540EE43392C68F50E40E9B5D95889CE454033E609DF56F50E40DD3532D989CE4540CB7B41B04FF50E40BA313D6189CE4540C6BE092A4FF50E4007CF842689CE45401298987851F50E404F67DDF588CE4540BFFEDAB05CF50E4043D3C89D88CE45407FA2B2614DF50E4002D0CDA387CE4540FF03519C48F50E402CC5443987CE454066E2B1FA7EF50E4003A8F3F285CE45400452071E84F50E40B07B86CB85CE454045EBF2F79CF50E404A68267387CE45402AB4626EADF50E40C022BF7E88CE4540BD00FBE8D4F50E4083A279008BCE4540	w75781789	75781789	way	yes	\N	\N	\N	12
134	0106000020E6100000010000000103000000010000000600000061D6D52EB7F50E40D92F8E80C0CE454063F9A9E0A6F50E40CD0B0B49C1CE4540D6862FB88BF50E4003250516C0CE4540D6862FB88BF50E404ABD5DE5BFCE4540AB18F89B9AF50E40B0123D3ABFCE454061D6D52EB7F50E40D92F8E80C0CE4540	w75781801	75781801	way	yes	\N	\N	\N	8
135	0106000020E610000001000000010300000001000000090000008BAABAA2EFF90E40995E077360CE4540B44CD07014FA0E40BB6AF9DC64CE4540F349383EA4F90E40C0C5D4A766CE4540A650CC30A4F90E40385ECB7564CE45400B5EF415A4F90E40157AB3BC61CE45408930348DDCF90E4093C9A99D61CE4540A144F064DCF90E40CE71C9CC60CE454081502855ECF90E408D54298760CE45408BAABAA2EFF90E40995E077360CE4540	w75781845	75781845	way	yes	\N	\N	\N	7
136	0106000020E6100000010000000103000000010000000E000000FC6EBA6587F80E40480845A973CE45400432E0D16BF80E40DD578A8972CE4540A73E90BC73F80E40AE77C94972CE4540896D9C5E73F80E40BA87DFA870CE454004649E4B27F80E404956348C71CE4540FD2FD7A205F80E40BB03E1AF6ECE454033E3C85E4AF80E40BCEF73D76DCE45403A1790076CF80E407BA4C16D6DCE4540FE54CB8C6DF80E40FD82DDB06DCE45402100DD3C7AF80E409214A28D6DCE4540ABA63517C9F80E4085A22F7370CE45405E5617A6A5F80E40C68B852172CE4540B9CFE0A58AF80E4095A58C6E73CE4540FC6EBA6587F80E40480845A973CE4540	w75781950	75781950	way	yes	\N	\N	\N	11
137	0106000020E610000001000000010300000001000000050000005C5837DE1DF90E401EC8D52368CE454047A4124317F90E400DD9E50066CE454027CD30FF32F90E407FF0EBD165CE454084BD892139F90E40D17245CE67CE45405C5837DE1DF90E401EC8D52368CE4540	w75781971	75781971	way	yes	\N	\N	\N	1
138	0106000020E610000001000000010300000001000000050000007ADDC77663F60E40990C6C3AA7CE45406015B9F138F60E40A55E0196A6CE454000E2AE5E45F60E4017067646A5CE4540CED02E956DF60E406AEA2BFEA5CE45407ADDC77663F60E40990C6C3AA7CE4540	w75781992	75781992	way	yes	\N	\N	\N	4
139	0106000020E610000001000000010300000001000000050000001F6FA8CE59F50E40904AB1A371CE4540E509849D62F50E409B4E571C73CE45403D409C2C5AF50E408A3F8A3A73CE4540BFE1F4E450F50E40FBB8ECC671CE45401F6FA8CE59F50E40904AB1A371CE4540	w75782006	75782006	way	yes	\N	\N	\N	\N
140	0106000020E6100000010000000103000000010000000900000010E1044B1AF80E40965929A9B8CE45404B5EF81CB3F70E40AE6DE580B8CE45405ED5592DB0F70E4024E0C61CBACE454056ED3FD763F70E40CBAE6AFFB9CE4540CC310F4F65F70E40543C8963B8CE45405FAB4E18DEF60E4048D6862FB8CE45403AFD4575DFF60E40BB698E07B6CE4540F2EF332E1CF80E4008ED3081B6CE454010E1044B1AF80E40965929A9B8CE4540	w75782021	75782021	way	yes	\N	\N	\N	7
141	0106000020E61000000100000001030000000100000006000000F988F3CBBBF50E40144438C192CE454077700BF1A3F50E40A3E47A8093CE45406F394D5590F50E4080CC183092CE4540B5728AE99DF50E408042E2C391CE4540F1513530A8F50E405C6CFF6F91CE4540F988F3CBBBF50E40144438C192CE4540	w75782038	75782038	way	yes	\N	\N	\N	5
142	0106000020E6100000010000000103000000010000000C00000065A5EE6F75F50E40ACB992D38DCE454084D382177DF50E404031B2648ECE45406D11627836F50E403FE3C28190CE4540FCE07CEA58F50E40F0259EFD92CE4540B3A1517067F50E4056D7A19A92CE45409150E91670F50E40D20CF32F93CE45402789809E61F50E40615111A793CE4540D8F8A7AF42F50E408A123EA594CE45401B98816F3FF50E407E0860B994CE45407274F0A721F50E4002D9469792CE454018A76B370BF50E408C6665FB90CE454065A5EE6F75F50E40ACB992D38DCE4540	w75782062	75782062	way	yes	\N	\N	\N	8
143	0106000020E61000000100000001030000000100000005000000D2BBC2CC88FC0E405232946EA6CE45402B12B81A7EFC0E407B698A00A7CE4540050A06216AFC0E40ECC84741A6CE45406577DC4B75FC0E402ED27AAEA5CE4540D2BBC2CC88FC0E405232946EA6CE4540	w75782067	75782067	way	yes	\N	\N	\N	13
144	0106000020E61000000100000001030000000100000010000000E027B3E66CF60E40DE36F867ABCE4540B279C14C80F60E40379666A9ABCE4540B7161C1483F60E4019F3846FABCE4540A29CC31094F60E40F6D4EAABABCE45405803EF3F8DF60E404E48C6C5ACCE45405329D1ED80F60E40ADA6EB89AECE45409D88D92670F60E40288E4D3CB1CE4540BF7A81FEE7F50E40008BA141AFCE4540652195BD00F60E40135E279AACCE4540834C327216F60E404A079046AACE454056D80C7041F60E40DE7EAFD7AACE45404921DAD836F60E40B46F93F6ABCE454096372CB242F60E40C0D5952AACCE45407FE9A3422BF60E409B971EA8AECE4540091C64ED4AF60E40005D8F1DAFCE4540E027B3E66CF60E40DE36F867ABCE4540	w75782070	75782070	way	yes	\N	\N	\N	10
145	0106000020E61000000100000001030000000100000017000000D70231BF89F70E40B8B87CDA97CE454018EEB7D15BF70E408BBF92509FCE4540242E5B4645F70E4054E81780A1CE4540835957BBDCF60E40FC8EE1B19FCE4540256310B3F2F60E40217134EC9CCE4540A0275426EBF60E40F7C374C69CCE45400C129150E9F60E40156756009DCE454032005471E3F60E4050F5D0E39CCE4540C955D1C4E0F60E4003FC64D69CCE45405C6B949AE2F60E406EE0698D9CCE45401F6C0C95DAF60E404533AA679CCE454087B9EEF7D5F60E407A747EE59CCE4540C9FE1E61BDF60E4015AF0D709CCE45403D03345BC3F60E4075FFFDCE9BCE45405F549CB4BAF60E4057A4D3049BCE45408B1C7D27C1F60E40B7F4C3639ACE45405DF7FB6AB3F60E40C9D57E219ACE454029E384AEE9F60E4055FF7B4B94CE45400520A45D3BF70E407E92962595CE454095B5F23746F70E40AE44454195CE454029AECF413CF70E40EE5BAD1397CE4540E6DC370884F70E406BBF10CD97CE4540D70231BF89F70E40B8B87CDA97CE4540	w75782077	75782077	way	yes	\N	\N	\N	15
146	0106000020E6100000010000000103000000010000000800000036261F16C5F60E4036559C0F74CE45406E4B89C9C0F60E40544035B973CE45403849F3C7B4F60E40FBFA6BC372CE4540A2D68FA8ABF60E407E69F6E571CE4540C938EBF8D4F60E40D8B4F74E71CE4540CCEF3499F1F60E402B291CE670CE454037F4609C09F70E4042EFE8DA72CE454036261F16C5F60E4036559C0F74CE4540	w75782117	75782117	way	yes	\N	\N	\N	6
147	0106000020E610000001000000010300000001000000070000001BC7FE68EEF70E40249FB2F567CE454058C6866EF6F70E4036AE7FD767CE454018A42AB7FEF70E40FABDA83869CE45405C430477FBF70E40B225506969CE454061003CFDFBF70E408ED9A38169CE4540ECBE6378ECF70E4071C0F8B369CE45401BC7FE68EEF70E40249FB2F567CE4540	w75782118	75782118	way	yes	\N	\N	\N	9
148	0106000020E610000001000000010300000001000000060000008A7780272DFC0E404DE03197AFCE454075898FF40EFC0E40A63FA0D8AFCE45406B2FFDA60BFC0E40CAA5F10BAFCE4540B4A8F4B814FC0E40D6AFCFF7AECE4540AF45668929FC0E40D04EBCB9AECE45408A7780272DFC0E404DE03197AFCE4540	w75782127	75782127	way	yes	\N	\N	\N	4
149	0106000020E610000001000000010300000001000000090000002881CD3978F60E4005EFF5FFBBCE4540E1F0DD4147F60E403F5D9324BECE45408146448C32F60E406A9AC129BDCE454030B374AA21F60E408E00135DBCCE4540F54A598638F60E40D07F0F5EBBCE4540ABEB504D49F60E40BE5CD5A3BACE4540183037CE5CF60E40A029858ABBCE45409C4B169C66F60E40A09F4E1EBBCE45402881CD3978F60E4005EFF5FFBBCE4540	w75782150	75782150	way	yes	\N	\N	\N	11
150	0106000020E6100000010000000103000000010000000800000046D1031F83F50E407216F6B4C3CE4540330BFEC8BEF50E40A30227DBC0CE4540E88B18D1D1F50E4026998BAEC1CE45401EE85729F3F50E40D899E72DC3CE4540FC5C2338E4F50E408A86D6D4C3CE4540DF1797AAB4F50E4047776BF4C5CE4540E6BADF579BF50E4036CAFACDC4CE454046D1031F83F50E407216F6B4C3CE4540	w75782197	75782197	way	yes	\N	\N	\N	11
151	0106000020E6100000010000000103000000010000000600000063658FABECF60E402B40CA3E7ECE4540B5A4A31CCCF60E40919BE1067CCE45404DE83FB50BF70E402DAE96E079CE454010406A1327F70E40BB48A12C7CCE454006E6D7C523F70E4091F7054F7CCE454063658FABECF60E402B40CA3E7ECE4540	w75782230	75782230	way	yes	\N	\N	\N	11
152	0106000020E610000001000000010300000001000000090000001F4F26C9CEF60E404B61399DBFCE454034E66498C9F60E4033C34659BFCE4540688E5143C0F60E40B6CF74C0BFCE4540A2B9A9DC9FF60E40EC8C4A45BECE4540FE00B562C9F60E405E7C7665BCCE4540BB7EC16ED8F60E405849754BBCCE4540335AFDC7F8F60E401C87B0D0BDCE454076F9D687F5F60E40F23515F3BDCE45401F4F26C9CEF60E404B61399DBFCE4540	w75782232	75782232	way	yes	\N	\N	\N	3
153	0106000020E610000001000000010300000001000000070000009B58E02BBAF50E401CA1551CBDCE45400E034CCFAAF50E40AB4198DBBDCE4540A67B9DD497F50E40997A8269BDCE454023BA675DA3F50E40460C9645BCCE45407093F6ABA5F50E40EDDA3928BCCE4540A9F523EAAAF50E4076BE4461BCCE45409B58E02BBAF50E401CA1551CBDCE4540	w75782257	75782257	way	yes	\N	\N	\N	11
154	0106000020E6100000010000000103000000010000001A000000E538019711F80E405EABF35E6BCE4540826B932F0DF80E40B295E1896ACE4540267B3A0D07F80E40290EFB986ACE454087EB072B04F80E40E7C2482F6ACE454010A738B302F80E400B0FF5166ACE4540064DA665FFF70E404DA25EF069CE454061003CFDFBF70E408ED9A38169CE45405C430477FBF70E40B225506969CE454018A42AB7FEF70E40FABDA83869CE454058C6866EF6F70E4036AE7FD767CE4540AFF9A70AFCF70E40BF3566C867CE45407A34D593F9F70E40A73B4F3C67CE4540D047197101F80E4066C28AAE66CE45404FE3834314F80E40A222F36D66CE4540973C9E961FF80E4013C42FAB66CE454083C53C8622F80E40E9CEB81567CE4540AB2A8FC93DF80E4001B562C966CE4540E7EC53443CF80E40A827E26366CE4540C7DBA56840F80E40F66805E165CE4540DA8CD31055F80E407FC2D9AD65CE4540F5FD2F325CF80E408423EDEB65CE454029C302A95EF80E4043ECA75A66CE45405C68F86063F80E4043ECA75A66CE4540E0A0BDFA78F80E40888CFD1B6ACE45406D65D35B4DF80E40B8C8E2A36ACE4540E538019711F80E405EABF35E6BCE4540	w75782314	75782314	way	yes	\N	\N	\N	13
155	0106000020E6100000010000000103000000010000000C00000021EE450FD7F50E400B98C0ADBBCE45409B58E02BBAF50E401CA1551CBDCE4540A9F523EAAAF50E4076BE4461BCCE45404765790DB0F50E40C35B8C26BCCE4540A8120AB6B6F50E40C3B7B06EBCCE45401E37FC6EBAF50E408ED20039BCCE4540F4AED579AFF50E400593D1B7BBCE45407093F6ABA5F50E40EDDA3928BCCE4540E8DDB3098BF50E40C4BDE8E1BACE4540508248D0A9F50E40956D9681B9CE454066B0F380C3F50E40C48FD6BDBACE454021EE450FD7F50E400B98C0ADBBCE4540	w75782321	75782321	way	yes	\N	\N	\N	8
156	0106000020E6100000010000000103000000010000000600000083FD3273DCF40E40821ABE8575CE4540CB1C812ED0F40E408368AD6873CE45402CB2423635F50E4025C2D03472CE45409799886D41F50E40C53D963E74CE454050CCD5EA06F50E40295F2BFC74CE454083FD3273DCF40E40821ABE8575CE4540	w75782343	75782343	way	yes	\N	\N	\N	7
157	0106000020E6100000010000000103000000010000000A0000005D8B16A06DF50E408C33E1F2B3CE4540E3C9C91F67F50E40338CBB41B4CE45406EA5D76663F50E408CBD175FB4CE454055E0BFD42AF50E40AB52C433B2CE4540C9586DFE5FF50E40410466CFAFCE45407A5C0AFE6DF50E401DD25E33AFCE4540CFA91A738DF50E408E3F51D9B0CE4540258392B87DF50E40A57BE761B2CE4540CBD2F31373F50E40C837256AB3CE45405D8B16A06DF50E408C33E1F2B3CE4540	w75782344	75782344	way	yes	\N	\N	\N	9
158	0106000020E61000000100000001030000000100000011000000537F187CF5FC0E4037C7B94DB8CE454023C621D1BAFC0E40C5C32055B9CE4540B8D6CD7B52FC0E4059F38876BACE4540751A0EF049FC0E404FAD6301B8CE4540EA78CC4065FC0E40A27DACE0B7CE45406FB488CD6CFC0E40C0208E1AB8CE4540532058FA75FC0E401E6B4606B9CE45406F2821FD9BFC0E40AE3FD35CB8CE4540E66FE7678FFC0E40D8C4B8D1B6CE4540789CA223B9FC0E40F6251B0FB6CE45404A97FE25A9FC0E40AAD6C22CB4CE45402E28C23C1AFD0E40759B2622B2CE4540C5BA021B21FD0E40E6F4ABEFB2CE454057ADF13E33FD0E400F266A0EB5CE4540510DA0843EFD0E405BBD7960B6CE4540F66EE29AF1FC0E40A24F9ABCB7CE4540537F187CF5FC0E4037C7B94DB8CE4540	w75782393	75782393	way	yes	Présidence Université de Montpellier - Services centraux et communs	\N	\N	15
159	0106000020E610000001000000010300000001000000080000005DF7FB6AB3F60E40C9D57E219ACE45408B1C7D27C1F60E40B7F4C3639ACE45405F549CB4BAF60E4057A4D3049BCE45403D03345BC3F60E4075FFFDCE9BCE4540C9FE1E61BDF60E4015AF0D709CCE45402A3520E7A2F60E401B2AC6F99BCE45400B613596B0F60E402E6DDD729ACE45405DF7FB6AB3F60E40C9D57E219ACE4540	w75782431	75782431	way	yes	\N	\N	\N	15
160	0106000020E6100000010000000103000000010000000C0000006C62DC685BF80E4072A197F672CE45400432E0D16BF80E40DD578A8972CE4540FC6EBA6587F80E40480845A973CE45400806103E94F80E40B300B73874CE4540D44334BA83F80E4035971B0C75CE4540E300553772F80E40706715EC75CE4540553431B841F80E40F437FCC973CE454097B32DB940F80E401884A8B173CE454087B949B148F80E406621F07673CE4540E966DA594FF80E40AD7191D673CE4540F2BD75B460F80E404EB10F5773CE45406C62DC685BF80E4072A197F672CE4540	w75782451	75782451	way	yes	\N	\N	\N	10
161	0106000020E61000000100000001030000000100000006000000F129A50CC1F60E40A1BF2BDDB8CE4540367DD179E8F60E404183A856BACE454005FBAF73D3F60E400B0E8A41BBCE45401BB2CB01CCF60E40AC61759ABBCE454003475DC6A8F60E40C57B69E5B9CE4540F129A50CC1F60E40A1BF2BDDB8CE4540	w75782460	75782460	way	yes	\N	\N	\N	4
162	0106000020E6100000010000000103000000010000000700000033B1AF2B1CF70E40672D605D70CE45408E812B8F24F70E4001BEDBBC71CE4540C8C969F40FF70E408ACFF81972CE45406E36B11B11F70E40130F289B72CE454037F4609C09F70E4042EFE8DA72CE4540CCEF3499F1F60E402B291CE670CE454033B1AF2B1CF70E40672D605D70CE4540	w75782466	75782466	way	yes	\N	\N	\N	3
163	0106000020E6100000010000000103000000010000003500000045EB4DB10FF70E40F7915B936ECE4540B9D27CDF09F70E40B10573AA6BCE4540B4322B2515F70E4028507A956BCE454092C4DCFF11F70E401747E5266ACE454000EFD3A70BF70E40FB39AA3F67CE4540DC23E53801F70E40BC5CC47762CE45404371C79BFCF60E4069AC585760CE4540E66091BAF8F60E400B4E33935ECE4540318EDB792CF70E4047AE9B525ECE45402BD1A3F32BF70E4071A312E85DCE45403D5AE6BEE6F60E40417B9A385ECE454038A0A52BD8F60E40E27261495ECE4540C11E1329CDF60E402C1D627259CE45407E7F3969D0F60E406DB0CB4B59CE4540409D972FD4F60E4079BAA93759CE45400D158843DBF60E406178DB3B59CE45406905E165E1F60E40912A8A5759CE45402D431CEBE2F60E40673513C259CE454079399105F1F60E40610212A859CE4540AF3E1EFAEEF60E40F0D69EFE58CE45406656A5E320F70E403E74E6C358CE454088388C3853F70E40F651578858CE4540626AA6D656F70E409615D4015ACE4540D7C8642772F70E40676325E659CE4540C691BD9470F70E40F637B23C59CE4540D1EB4FE273F70E409D06561F59CE454098A608707AF70E40CD5CE0F258CE4540FDD0162186F70E40853A51B758CE4540CA4807358DF70E400EC237A858CE45409B5D521097F70E407F07509D58CE454001A83D80A0F70E40CD00BCAA58CE4540D879C0E1AAF70E40793073CB58CE4540B5087BC9B5F70E4002147E0459CE454021109EBFBFF70E40D2EB055559CE45405F2F0384C5F70E40AEFB7DB559CE4540989130C2CAF70E4067BF492E5ACE4540851ACFB1CDF70E4043CFC18E5ACE4540DE8DAACBCEF70E40F5E9C2595BCE45409D2E8B89CDF70E40426D65D35BCE4540BD3F3965C9F70E401273FF475CCE45408BBA206CC2F70E40B927FEDE5CCE4540638F9AC0BEF70E40EE0CAE145DCE4540BF620D17B9F70E40BEB623415DCE454021F3B7F3B3F70E402F2A4E5A5DCE4540838362D0AEF70E40EE96E4805DCE4540748C75BBA8F70E40DC87179F5DCE4540B70E69AF99F70E403BEC74D65DCE45403B0D62B197F70E40E863E3665DCE4540FB39AA3F67F70E402F8672A25DCE4540F713DF9A85F70E40115663096BCE4540F730C56691F70E40829B7BFE6ACE45406C55B71F95F70E40F26492EC6CCE454045EB4DB10FF70E40F7915B936ECE4540	w75782489	75782489	way	yes	\N	\N	\N	10
164	0106000020E61000000100000001030000000100000007000000F1513530A8F50E405C6CFF6F91CE45403851A62C9EF50E40800063C790CE45401B46E63686F50E4087DD770C8FCE45404628B682A6F50E40AB15B71B8ECE45407E8AE3C0ABF50E408D2A1E728ECE45408DBB9C6DC9F50E402773E26190CE4540F1513530A8F50E405C6CFF6F91CE4540	w75782491	75782491	way	yes	\N	\N	\N	3
165	0106000020E610000001000000010300000001000000060000009B6A77595DF80E404B5645B8C9CE4540174F988B53F80E4005680014C8CE4540D8A3CBF67CF80E4005680014C8CE45404EE89A6E7EF80E40E11B542CC8CE4540FB31F7DA7DF80E40F857EAB4C9CE45409B6A77595DF80E404B5645B8C9CE4540	w75782492	75782492	way	yes	\N	\N	\N	8
166	0106000020E6100000010000000103000000010000000C00000042902859F3F80E40BD6B75DE6BCE45404FBEEA121FF90E40BC653D6B6DCE4540217C838A05F90E40032670EB6ECE45404F0D8F58E6F80E402CFB09C270CE4540ED5FFEAFDFF80E40A317FF8870CE4540479C0425BBF80E403206312B6FCE45403A1F9E25C8F80E403925C56C6ECE454017AE580DD3F80E40FDF26ED16ECE4540226294B1EBF80E40E6E4EA6C6DCE454046D3D9C9E0F80E403F5EFEF96CCE4540B65A71BBE1F80E40C8E5E4EA6CCE454042902859F3F80E40BD6B75DE6BCE4540	w75782511	75782511	way	yes	\N	\N	\N	9
167	0106000020E61000000100000001030000000100000008000000C948AC7B1AF60E403D47E4BB94CE454079D5B95807F60E4002EDB36F93CE45402B9F8AC0FDF50E40C145DDBD92CE45408CC0B39833F60E40A4D6451B91CE45407709980A3BF60E405C9A119491CE45404EF8003851F60E405B66C7FC92CE45407949528836F60E40433866D993CE4540C948AC7B1AF60E403D47E4BB94CE4540	w75782512	75782512	way	yes	\N	\N	\N	12
168	0106000020E6100000010000000103000000010000000F000000B19B638A83F50E4093FDF33460CE45407A96D69585F50E4004858B2661CE454042716CE289F50E402D88372163CE454064DFBA078DF50E40264FFE9364CE4540F217699890F50E407E7A223E66CE4540617F23CB93F50E40CB3F44B467CE4540416E75EF97F50E40A64984A169CE454068791EDC9DF50E40876C205D6CCE4540756506E055F50E40E6FE8FB86CCE454000242E5B46F50E4087F656C96CCE4540708EDF803BF50E40FE6E70D86CCE4540ECC1A4F8F8F40E40099EE7F461CE45403C8F407221F50E4069780EC061CE454049298D3D20F50E40224212AC60CE4540B19B638A83F50E4093FDF33460CE4540	w75782529	75782529	way	yes	\N	\N	\N	10
169	0106000020E6100000010000000103000000010000000500000036D71F178BF50E4092F9916CBFCE45404C8E3BA583F50E409E8DA6C4BFCE4540928DACA179F50E407A89B14CBFCE4540120C31A880F50E406FF59CF4BECE454036D71F178BF50E4092F9916CBFCE4540	w75782553	75782553	way	yes	\N	\N	\N	12
170	0106000020E6100000010000000103000000010000000500000072F096F5ACF50E409561DC0DA2CE4540B169A510C8F50E40964D6F35A1CE4540390202E7D6F50E4054CE7234A2CE45403B08F0CCBAF50E40D05FE811A3CE454072F096F5ACF50E409561DC0DA2CE4540	w75782571	75782571	way	yes	\N	\N	\N	6
171	0106000020E6100000010000000103000000010000001700000097B32DB940F80E401884A8B173CE4540553431B841F80E40F437FCC973CE4540E300553772F80E40706715EC75CE454025ECDB4944F80E400A3A104878CE4540C16D122807F80E4097E8876C7BCE4540C3ADCCA502F80E4008D27B197BCE4540552C239AE5F70E405D1EC6FF78CE454093D4F83BCAF70E40CF83BBB376CE45406DE92C0EC2F70E40769A160676CE4540ABCBCE47BEF70E408EDCE40176CE4540EF6D9FFAACF70E40A6A8E96976CE454021D6D127A8F70E406A6226F675CE454085A636829EF70E40F4D59F0E75CE45400322C495B3F70E406591819774CE4540D1B99168B8F70E4059E3C7F374CE4540413E3267C7F70E40BE94CB9074CE4540F91EE4ABD3F70E40EE467AAC74CE4540C9303894EBF70E403507AD2C76CE45402FEFBB3324F80E4030DAE38574CE45406937FA980FF80E403C180C0973CE45404469143713F80E40D1F1875572CE45409D3699A729F80E40EA7B0DC171CE454097B32DB940F80E401884A8B173CE4540	w75782574	75782574	way	yes	\N	\N	\N	13
172	0106000020E61000000100000001030000000100000008000000F7FB6AB356F90E40BD0C10165FCE454059A9FB5B5DF90E40EC9EE17261CE454007301B5366F90E407F0A911D65CE45400BAD985B6BF90E40B3452D2867CE454026E71FD84CF90E40F590DF9167CE4540348463963DF90E403F3BE0BA62CE4540DAD3C4F132F90E4046F01A4F5FCE4540F7FB6AB356F90E40BD0C10165FCE4540	w75782575	75782575	way	yes	\N	\N	\N	9
173	0106000020E61000000100000001030000000100000009000000B52792F991FC0E40F4D43439C6CE4540F9A985ED82FC0E4043C6A354C2CE45409B0DE83BAEFC0E40AFAAA80BC2CE4540AA46AF0628FD0E408B1C7D27C1CE45400BF148BC3CFD0E40A76B370BC5CE4540499C155113FD0E40BF092A4FC5CE4540CC5D4BC807FD0E4048BF2264C5CE4540F1D187D3EEFC0E40AD286F91C5CE4540B52792F991FC0E40F4D43439C6CE4540	w75782578	75782578	way	yes	\N	\N	\N	12
174	0106000020E6100000010000000103000000010000000500000013F9E41714FC0E40644227DFC7CE4540C042418413FC0E406AEBF18CC7CE454040DEAB5626FC0E402FD3403DC7CE454027AA12C028FC0E402F2F6585C7CE454013F9E41714FC0E40644227DFC7CE4540	w75782583	75782583	way	yes	\N	\N	\N	\N
175	0106000020E6100000010000000103000000010000000D0000002A7E422C51FC0E40A4AC3A06BFCE4540112DC3C947FC0E40B0E42A16BFCE4540C9F08E4248FC0E406F51C13CBFCE4540D23F1C7FFDFB0E406E090ACDBFCE4540A9F4B814FCFB0E40157C8967BFCE4540CEC29E76F8FB0E4045BEA662BECE454045EA8722EEFB0E4039B4C876BECE45403DED951EF2FB0E409E31827CBFCE45407341C758B7FB0E401B39C1EDBFCE45407B3EB95CB3FB0E408C6A6C0ABFCE45407FBE2D58AAFB0E40F39771AEBCCE4540E9013D1E44FC0E40EDF4DE73BBCE45402A7E422C51FC0E40A4AC3A06BFCE4540	w75782585	75782585	way	yes	\N	\N	\N	11
176	0106000020E6100000010000000103000000010000000C000000D88926AB7DF50E400A534ABEC8CE45400AD5720C6DF50E4064703903C8CE4540EF096D9450F50E403A8F2F46C9CE4540F7CC920035F50E408EEFE604C8CE454043A6214F37F50E40520548D9C7CE45402935C52D30F50E4052A92391C7CE45404149810530F50E407C4276DEC6CE4540BFA7284D39F50E40003B376DC6CE4540C4279D4830F50E40D63153FFC5CE45404E5A5DF34FF50E40D1329C7CC4CE454055E5D6FF94F50E40701EF3A6C7CE4540D88926AB7DF50E400A534ABEC8CE4540	w75782602	75782602	way	yes	\N	\N	\N	12
177	0106000020E6100000010000000103000000010000000E00000026FA21DB9EF50E40DF9E8C96A8CE4540E5F1B4FCC0F50E4075C0BF52A7CE45403A3FC571E0F50E40F76A91FEA8CE454021D15F43CBF50E4055F7C8E6AACE45400F5DF525C0F50E403DF779E7ABCE45400AC09A5EBDF50E40EF593222ACCE4540BEE60B10BBF50E4043869F49ACCE45404D5F741EBAF50E402B44D14DACCE4540DDD7DC2CB9F50E40C003A84EACCE4540241411B4B8F50E40C003A84EACCE4540B48C79C2B7F50E4043869F49ACCE454010093AB58EF50E403EA18D12AACE45405708ABB184F50E4038E4558CA9CE454026FA21DB9EF50E40DF9E8C96A8CE4540	w75782609	75782609	way	yes	\N	\N	\N	11
178	0106000020E6100000010000000103000000010000000E000000ABEB504D49F60E40BE5CD5A3BACE4540F54A598638F60E40D07F0F5EBBCE4540679B1BD313F60E409BA0979BB9CE4540FE4A427D26F60E400D0055DCB8CE454061527C7C42F60E409C1C99A2B7CE45407F068A0E37F60E4037291609B7CE454035A781D547F60E402606DC4EB6CE4540AACB738E4BF60E40B592B135B6CE45406CE9D1544FF60E403815A930B6CE4540DEAD2CD159F60E40DE9B95A3B6CE45404875954968F60E40A327C00BB6CE4540D0679B768CF60E400D90C3BBB7CE45404078A3456CF60E40B95D1E21B9CE4540ABEB504D49F60E40BE5CD5A3BACE4540	w75782612	75782612	way	yes	\N	\N	\N	8
179	0106000020E610000001000000010300000001000000050000009C757C6AABF80E402429E96168CE4540E3CB9FCAC4F80E40360AA41F68CE4540C29A1430CBF80E40894A7E1F69CE454029AE2AFBAEF80E406B5FE57569CE45409C757C6AABF80E402429E96168CE4540	w75782621	75782621	way	yes	\N	\N	\N	3
180	0106000020E6100000010000000103000000010000000A000000C2CA57B89BF60E4083723678BACE4540760EAF35A5F60E40A6762BF0BACE4540CEED146179F60E40ABFF18DFBCCE4540795160A692F60E40F2632717BECE4540FF1884036BF60E4027439FD9BFCE454016D3968455F60E402D060FD3BECE4540E1F0DD4147F60E403F5D9324BECE45402881CD3978F60E4005EFF5FFBBCE454086EBAC7191F60E406BBA9EE8BACE4540C2CA57B89BF60E4083723678BACE4540	w75782628	75782628	way	yes	\N	\N	\N	8
181	0106000020E6100000010000000103000000010000000B0000006C9AD25515F50E404F96B5A8AACE45401667B1B90FF50E401A3B3CDFAACE45409F718687D5F40E4057D526A9A7CE4540D09CF529C7F40E40CE39D3DFA6CE45400753DED8FDF40E40F90670C4A4CE4540CBADFF290BF50E40226C787AA5CE454006161B4EF4F40E402280E552A6CE4540A4DC22D51CF50E400F23298EA8CE4540B66D73BE33F50E40A4CE92B6A7CE4540E1325D3E48F50E40AA4313CDA8CE45406C9AD25515F50E404F96B5A8AACE4540	w75782632	75782632	way	yes	\N	\N	\N	8
182	0106000020E610000001000000010300000001000000080000001E4FCB0F5CF50E4073672618CECE45400A9BA67455F50E401F69CB14CECE4540D395198057F50E40E0579BB5CACE45408C59E5F857F50E407B1C61ACCACE45406D6814DC59F50E40812150A2CACE45409E9B919CA7F50E40E0579BB5CACE45401DDD5218A5F50E40E4DA5031CECE45401E4FCB0F5CF50E4073672618CECE4540	w75782640	75782640	way	yes	\N	\N	\N	13
183	0106000020E61000000100000001030000000100000009000000685485ABA8F60E40053F60D4A4CE4540A8C87C9B59F60E40B2182B20A3CE4540D5905D0E60F60E4006312B6FA2CE45402984C42C6AF60E40D73CFD56A1CE4540E2BE1FC88BF60E40B3D6AB23A2CE45403F092241A7F60E40D003C4C9A2CE454056E01A8E9DF60E40710FF8B2A3CE45404DE03197AFF60E409A18DC20A4CE4540685485ABA8F60E40053F60D4A4CE4540	w75782646	75782646	way	yes	\N	\N	\N	7
184	0106000020E61000000100000001030000000100000006000000720D7DC1B8F50E4021FD9BBC6DCE4540DE14A0B7C2F50E4075CDE49B6DCE454095B88E71C5F50E40A45181936DCE4540A6EF3504C7F50E40DA6443ED6DCE4540D03D9061BAF50E40C25087156ECE4540720D7DC1B8F50E4021FD9BBC6DCE4540	w168310910	168310910	way	yes	\N	\N	\N	\N
185	0106000020E610000001000000010300000001000000AA0000008C40063C7AFD0E40ED66A1F88CCE4540607825C973FD0E40B20639398DCE45407AE981EA7AFD0E401199A8948DCE45402AB05B5F7FFD0E4029AD646C8DCE45407940344E9EFD0E40B2BE81C98DCE454009B99C5C9DFD0E4058E949F48DCE454068098DBB9CFD0E40D5C276418ECE4540CF19AC938EFD0E40647D5E4C8ECE454057B5FF5C8FFD0E4028791AD58ECE4540CCF6D7E19EFD0E4004FF5BC98ECE45406DA6E7829FFD0E4087AF65E88ECE4540E9A7EE80A1FD0E405254EC1E8FCE4540A82BE97294FD0E4057E311818FCE454087FA5DD89AFD0E40FE69FEF38FCE4540E08A1FBEA7FD0E40225A86938FCE45404FF2D9F0AAFD0E40F203FCBF8FCE454070404B57B0FD0E407BE706F98FCE4540290417D0B0FD0E40CEE561FC8FCE4540EB048FCAA8FD0E409E190E9590CE4540F2FE89DBB2FD0E4009B65BDC90CE4540CAF0E9FBBAFD0E40A4C2D84290CE454093EB5C07BDFD0E40337DC04D90CE4540C5707500C4FD0E40A4F0EA6690CE45407D1464BAC6FD0E40216EF36B90CE454077572C34C6FD0E40DF92D22291CE454077741200D2FD0E405C10DB2791CE45407C314A86D2FD0E40B028DB7690CE454031957EC2D9FD0E40216EF36B90CE45405E5D5F35E0FD0E402D78D15790CE4540A239FC7FE6FD0E40F7A68EFA90CE454096DC723FF1FD0E4003835AC290CE4540B70DFED9EAFD0E40E655421C90CE4540A4969CC9EDFD0E40F25F200890CE4540FBC9BD65F3FD0E4028BB99D18FCE45405FB7088CF5FD0E40F808EBB58FCE45404C7D6A0602FE0E407B15191D90CE4540E40FABE408FE0E40288D87AD8FCE4540DE358D92FCFD0E40CFFF06488FCE4540893F2F8100FE0E4081AA76F28ECE454047FAFE1719FE0E40048992358FCE4540057B02171AFE0E40222C746F8FCE45406BC5ED8623FE0E4016F4835F8FCE45405F4B7E7A22FE0E401C9D4E0D8FCE4540170C530031FE0E40405FC4888ECE45402D00321933FE0E4064AB70708ECE45407B1684F23EFE0E408D5830968ECE45400292FAFC41FE0E40C35785178ECE454067823C1636FE0E4005EBEEF08DCE454098E777503FFE0E40713150638CCE45404B0BF20E4BFE0E40DC9F8B868CCE45409DA1B8E34DFE0E407DDF09078CCE45409D84D21742FE0E401271CEE38BCE4540E04092A34AFE0E401EAFF6668ACE454021BD97B157FE0E40079B3A8F8ACE4540255AF2785AFE0E402558C1148ACE454032D758784DFE0E403C6C7DEC89CE454092640C6256FE0E409170106388CE4540B052E68B62FE0E40E49C7D8A88CE45409CDB847B65FE0E40C69D770888CE45407FEDAA5159FE0E409DF0B7E287CE454086048C2E6FFE0E409F16CD1484CE45403EE53D737BFE0E40C8C38C3A84CE45402B6EDC627EFE0E408145D9B683CE454017BDAEBA69FE0E40E624EF7783CE4540F9426DC08CFE0E40AEAE54617DCE45405AD020AA95FE0E407220DA7D7DCE454059B043EB97FE0E4084D382177DCE45407B01AC448FFE0E405521D4FB7CCE4540E48B513294FE0E402C8EB9217CCE4540B6C079CC9BFE0E40097657D17ACE45409A2C49F9A4FE0E40CDE7DCED7ACE454069E4F38AA7FE0E40BB20C77B7ACE4540387FB8509EFE0E408C6E18607ACE4540A1095E3EA3FE0E404B992F8A79CE4540721EA919ADFE0E400F0BB5A679CE454038B984E8B5FE0E4033294F6A79CE454049F02B7BB7FE0E40094E7D2079CE45402B3C1EE9C2FE0E40E0FCE14279CE454088693A96D2FE0E40C31DB97F76CE4540272B2BF290FE0E40B8FF6DBB75CE45403982AF4390FE0E40A6F0A0D975CE45403605323B8BFE0E402F7887CA75CE4540E02BBAF59AFE0E40545ADA0473CE454069C70DBF9BFE0E407ED9870673CE454031A2A30BA0FE0E40BF9A030473CE4540C4978922A4FE0E401EA33CF372CE454004D7CBA5A7FE0E405A31B7D672CE45406D814E52AAFE0E40724573AE72CE45407EB8F5E4ABFE0E40781C508072CE4540E9825550ACFE0E409635FB4D72CE454013EE9579ABFE0E40490E7D1C72CE454097EC8E7BA9FE0E40786407F071CE45405D6A847EA6FE0E407836F5CB71CE45409B4C26B8A2FE0E4007C3CAB271CE45406D6468869EFE0E40E4480CA771CE4540A589D2399AFE0E40A28790A971CE45401294EC2296FE0E40437F57BA71CE4540D354AA9F92FE0E409CB0B3D771CE454069AA27F38FFE0E40EFDC20FF71CE45409315681C8FFE0E4060504B1872CE4540456BA05456FE0E405B65016E71CE4540633C94B256FE0E40F6FBB44071CE45408DA7D4DB55FE0E40A8D4360F71CE454011A6CDDD53FE0E40D82AC1E270CE4540D723C3E050FE0E40D8FCAEBE70CE454061FFD0274DFE0E40678984A570CE4540341713F648FE0E40430FC69970CE45401E43119C44FE0E40024E4A9C70CE4540D946979240FE0E40A34511AD70CE45409907550F3DFE0E40FC766DCA70CE4540305DD2623AFE0E404FA3DAF170CE4540D12CBFC238FE0E40DE8BD42071CE4540B45BCB6438FE0E402BB3525271CE454089F08A3B39FE0E4079DAD08371CE454005F291393BFE0E40498446B071CE45403F749C363EFE0E4049B258D471CE4540B5988EEF41FE0E40BA2583ED71CE45409D84D21742FE0E404FE559EE71CE4540BD789A2732FE0E4024FE17BE74CE45405F6864462EFE0E40D604ACB074CE4540E803B80F2FFE0E40065B368474CE45401CFB4800EDFD0E40D1BD3DBE73CE4540038DE3D1D7FD0E40E7ABE46377CE454009104FC0C0FD0E401C63827577CE4540B439CE6DC2FD0E40E61B768478CE4540787709F3C3FD0E40C2E3367579CE4540516C6006BEFD0E402D24607479CE4540CE16B5A09CFD0E407100FDBE7FCE4540D7506A2FA2FD0E407D66FFF27FCE4540244AD63CA2FD0E40470B862980CE454065A9F57EA3FD0E40B2E9526D81CE454032CA332F87FD0E405DF3F45B85CE454098F738D384FD0E405DF3F45B85CE4540DFF6A9CF7AFD0E409DAE38E686CE45402039E34570FD0E405CBFAAC486CE4540C328AD646CFD0E40BBAD3E6887CE4540C15774EB35FD0E40CD04C3B986CE4540723E2B1F38FD0E401B74F85A86CE4540FE39162532FD0E40BB3DAD4786CE4540176EAFBB2FFD0E403E4ADBAE86CE45401074B4AA25FD0E4026DAFA8E86CE4540CA575DE223FD0E4050B5CCD886CE4540D15158F32DFD0E406825ADF886CE4540D014956824FD0E40379BD88D88CE45409FAF592E1BFD0E40DE697C7088CE4540F385DA8019FD0E40B446F3B688CE454024EB15BB22FD0E400D784FD488CE4540C47D3F9017FD0E4060CC96AC8ACE454064F08BA60EFD0E409B5A11908ACE4540A0B250210DFD0E40CB3AD2CF8ACE45400140040B16FD0E408FAC57EC8ACE4540374591FF13FD0E4071C1BE428BCE45405E503AEC19FD0E40D1F709568BCE4540274BADF71BFD0E40EEE2A2FF8ACE45402BE510CC2CFD0E4024C852358BCE4540AFE309CE2AFD0E40711DE38A8BCE45400BD462F030FD0E406513059F8BCE4540D4CED5FB32FD0E4083FE9D488BCE4540558A1D8D43FD0E402424777D8BCE4540F09CD26641FD0E40EEF60FD88BCE45404D8D2B8947FD0E404D2D5BEB8BCE4540B17A76AF49FD0E40181A99918BCE45403ED00A0C59FD0E40D08140C28BCE4540D9E2BFE556FD0E40C4D3861E8CCE4540E8D9ACFA5CFD0E40230AD2318CCE45409AC0632E5FFD0E4030B88BD58BCE4540707209D16BFD0E40AC63A6FE8BCE4540B7AE3D586BFD0E40CAD875148CCE4540E7F39BD376FD0E40CA0688388CCE45408C40063C7AFD0E40ED66A1F88CCE4540	w272804945	272804945	way	cathedral	Cathédrale Saint-Pierre	place_of_worship	fr:Cathédrale Saint-Pierre de Montpellier	0
186	0106000020E610000001000000010300000001000000070000005C21ACC612F60E40F91C0E0176CE4540EEF9AB110BF60E40527C7C4276CE4540B9BD4978E7F50E40A7C8C62874CE4540B3AE76B92DF60E405ABBED4273CE454024360EAB2EF60E409BAA7B6473CE45405C21ACC612F60E40B28AEDA474CE45405C21ACC612F60E40F91C0E0176CE4540	w574970942	574970942	way	yes	\N	\N	\N	\N
187	0106000020E610000001000000010300000001000000050000008E5FD3DE3BF50E409F65CC13BECE45401958C7F143F50E40DA4F6B3FBECE45400CA1945A39F50E4092CB7F48BFCE4540E7B5C82C31F50E4057E1E01CBFCE45408E5FD3DE3BF50E409F65CC13BECE4540	w722621485	722621485	way	roof	Saint-Roch	\N	\N	\N
188	0106000020E6100000010000000103000000010000000F000000FA5D7DE13AFB0E401DB8B9E7AFCE4540264344204DFB0E4035CC75BFAFCE45404CDF6B088EFB0E40A054562EAFCE4540357C0BEBC6FB0E40D653ABAFAECE4540E085ADD9CAFB0E40CA5D3A9CAFCE45406B2FFDA60BFC0E40CAA5F10BAFCE454075898FF40EFC0E40A63FA0D8AFCE45400E59935D1FFC0E409915E52DB2CE45406396E24FF9FC0E40FAB9FCE2ADCE4540586E0E7CB1FC0E40E7AFEB72A5CE4540035BCA9EA9FC0E405EE68585A4CE4540419FC893A4FB0E40DA9FD513A7CE45401F8315A75AFB0E402E8AC33EA6CE45406F6589CE32FB0E40122ADD02AECE4540FA5D7DE13AFB0E401DB8B9E7AFCE4540	w970913661	970913661	way	yes	Délégation Militaire Départementale de l’Hérault (DMD34)	\N	\N	\N
\.


--
-- Data for Name: footways; Type: TABLE DATA; Schema: pgmetadata_demo; Owner: -
--

COPY pgmetadata_demo.footways (id, geom, full_id, osm_id, osm_type, highway, name, bicycle, lit, surface) FROM stdin;
1	0102000020E610000002000000D23B702942F50E407FF964C570CE4540DBAFF14F5FF50E40BE7A264575CE4540	w23319596	23319596	way	steps	Allée Jean Raymond	\N	\N	\N
2	0102000020E61000000500000033839D071CFE0E408D576A076DCE4540C438C9A024FE0E400FD4298F6ECE454040529F3FC8FD0E407A56D28A6FCE4540B1BC5065BDFD0E405B7FA6B970CE45408CFE863F79FE0E40C14A4FA26FCE4540	w78194365	78194365	way	footway	\N	\N	yes	sett
3	0102000020E610000002000000EC6B5D6A84FE0E40D4A70B676DCE4540C438C9A024FE0E400FD4298F6ECE4540	w78194366	78194366	way	steps	\N	\N	\N	\N
4	0102000020E6100000100000001416269D92FD0E40F538C25895CE4540E0BFD42A55FD0E4080C1244B9CCE4540734122122AFD0E402D3993DB9BCE45400B43E4F4F5FC0E40FF02E6C699CE4540E97DE36BCFFC0E4007D2C5A695CE4540455156C2C9FC0E4090E91A7794CE45408470BB86CFFC0E4002918F2793CE45409DDE20B5E4FC0E40AF22A30392CE4540E0D4ACD804FD0E40BCA24A8391CE4540CCB4FD2B2BFD0E40213AA9D491CE4540FC6DF4D665FD0E40BBCA243493CE45401416269D92FD0E40F538C25895CE454019ED4CFCACFD0E400D61EB0896CE4540AD799FF4CFFD0E404274AD6296CE45404E637B2DE8FD0E404803D3C496CE4540189BB1C3F3FD0E40D09E268E97CE4540	w78195779	78195779	way	footway	\N	\N	yes	concrete
5	0102000020E610000008000000385AC46636FE0E40367E3C4F97CE4540189BB1C3F3FD0E40D09E268E97CE4540E99216D3F1FD0E401CBA34D99ACE454042CC2555DBFD0E407589343B9CCE4540D1CDFE40B9FD0E40EBB996DA9CCE4540E0BFD42A55FD0E4080C1244B9CCE454046764AAC31FD0E40F056F1A19FCE4540E6EB8DB51AFD0E40F5279600A1CE4540	w78195780	78195780	way	footway	\N	\N	yes	\N
6	0102000020E6100000040000000D80023972FE0E409016670C73CE454070308AD46AFE0E40781C508072CE45408CFE863F79FE0E40C14A4FA26FCE4540EC6B5D6A84FE0E40D4A70B676DCE4540	w104799922	104799922	way	footway	\N	\N	yes	\N
7	0102000020E6100000040000008CFE863F79FE0E40C14A4FA26FCE4540A9D491C8E3FE0E4020F12BD670CE4540E9BC21E8C3FE0E40836275F574CE4540350A4966F5FE0E404159428875CE4540	w104799923	104799923	way	footway	\N	\N	yes	sett
8	0102000020E6100000080000003D5A417859F80E40B99C5C9DADCE45404DA3C9C518F80E40674815C5ABCE45406E9A88C8FAF70E40F678C663ABCE4540B11C7CBCEBF70E403D111F33ABCE45400A568B3ED5F70E406D533C2EAACE4540927A4FE5B4F70E406ECF3D35A8CE4540E9B06774ACF70E403F092241A7CE4540E9B06774ACF70E401C7BF65CA6CE4540	w108361151	108361151	way	footway	\N	\N	\N	\N
9	0102000020E610000009000000B9E92A3817FA0E402B508BC1C3CE4540B9E92A3817FA0E40CD391D6DC1CE4540B9E92A3817FA0E40B56D1805C1CE45403868AF3E1EFA0E40A0713CFABACE45405BF6DA221FFA0E40DDC36F54B8CE4540097DFA1928FA0E40FDDCD0949DCE454071BA1BFADDFA0E4028716770A5CE45402BBEA1F0D9FA0E400E547C32B5CE45403868AF3E1EFA0E40A0713CFABACE4540	w108361152	108361152	way	footway	\N	\N	\N	\N
10	0102000020E610000004000000DD45F35BCFFB0E4020C4DF4092CE454011209E8081FB0E40F1FDC34C91CE4540EFEEB72C15FA0E405FACB9ED8CCE454039888CFD1BFA0E404DD136A38BCE4540	w108361153	108361153	way	footway	\N	\N	\N	\N
11	0102000020E610000006000000724CBB3DADF70E404BDC74159CCE45402B306475ABF70E402FA1270A99CE454031D0B52FA0F70E40EA7CD34F93CE4540493B246BC3F70E40860552BD90CE454087B13B93ECF70E40AEB195E189CE4540B17D12E9C8FB0E4007488F3A95CE4540	w108361154	108361154	way	footway	\N	\N	\N	\N
12	0102000020E610000010000000E62329E961F80E403FB8F1DD9CCE4540522B4CDF6BF80E40F38876BA98CE4540097DFA1928FA0E40FDDCD0949DCE45407BB5EDC561FA0E40EB15BB229DCE4540721CD36E4FFB0E4043F9275D9FCE454062D0532E9EFB0E40C70B8E379ECE4540845B881FADFB0E40ABD0402C9BCE4540B17D12E9C8FB0E4007488F3A95CE4540DD45F35BCFFB0E4020C4DF4092CE4540D9A89894CCFB0E403A121E238FCE45404F649C757CFA0E404CCA38A16BCE454049F6083543FA0E4047414BB269CE4540AE72B21E08FA0E4047414BB269CE4540688B10C3B3F90E40C85BAE7E6CCE45408DDA58E432F90E407EAB75E272CE45404F7C105DABF80E4057D11F9A79CE4540	w108361155	108361155	way	footway	\N	\N	\N	\N
13	0102000020E6100000020000002D6F586485FC0E40F6132928A0CE4540D0413CB775FC0E4061264003A0CE4540	w108361156	108361156	way	footway	\N	\N	\N	\N
14	0102000020E61000000300000062D0532E9EFB0E40C70B8E379ECE4540E8FE452B52FC0E405B69087D9FCE4540B17D12E9C8FB0E4007488F3A95CE4540	w108361157	108361157	way	footway	\N	\N	\N	\N
15	0102000020E6100000070000008CCDD8E1F9F60E4068E7340BB4CE4540DB7FAEC78EF70E40090D0E40B4CE4540A1D0FC7B3AF80E407AAE4A7DB4CE4540F266C3503DF80E40D6427F57BACE45408170AA5A77F80E403579CA6ABACE45401B50CAFF3FF90E404D17BDAEBACE45403868AF3E1EFA0E40A0713CFABACE4540	w108361159	108361159	way	footway	\N	\N	\N	\N
16	0102000020E61000000F000000A1D0FC7B3AF80E407AAE4A7DB4CE454072E5475744F80E40A5DD431DB1CE45403D5A417859F80E40B99C5C9DADCE45401209F02774F80E4091E16712ABCE4540B9CFE0A58AF80E4057790261A7CE4540DC7AF25597F80E404CBD1358A5CE4540B53286DE87F80E40CA26AF84A4CE4540EAC083B064F80E40D0CF7932A4CE45403D5A417859F80E403C72FFECA2CE4540C47B0E2C47F80E4018E4D308A2CE45409D3699A729F80E404EB51666A1CE454002B04B9EFCF70E40A2855F45A1CE4540E10A28D4D3F70E40071DBE96A1CE45403C4A253CA1F70E40D14B7B39A2CE45401DA8F8646AF70E40D6DAA09BA2CE4540	w108361160	108361160	way	footway	\N	\N	\N	\N
17	0102000020E61000000A00000081A268D432F80E40332D5679A7CE4540DD75DB2A2DF80E40D4E29D8DA6CE4540CE273CB203F80E40F29F2413A6CE4540AD7F21F5E8F70E400525BB88A5CE4540989130C2CAF70E40B15472A9A5CE4540E9B06774ACF70E401C7BF65CA6CE4540BDCBA0359AF70E406ABC19DAA5CE454091E6D9F687F70E40E1D80EA1A5CE45406F3EBF396DF70E403A387DE2A5CE45407041B62C5FF70E409FCFDB33A6CE4540	w108362033	108362033	way	footway	\N	\N	\N	\N
18	0102000020E610000012000000DB7FAEC78EF70E40090D0E40B4CE4540180B9E9D67F70E406A21B715B1CE4540300274A95BF70E40CB63720FAECE4540DE6BADD458F70E403ECF9F36AACE45407041B62C5FF70E409FCFDB33A6CE45401EABEF575CF70E401DF7F763A4CE45401DA8F8646AF70E40D6DAA09BA2CE4540584AE0206BF70E40EADB3818A0CE4540E719FB928DF70E40447529649DCE4540724CBB3DADF70E404BDC74159CCE4540809A5AB6D6F70E40A5F9635A9BCE45408CE20B491CF80E40C84510429BCE45402869595249F80E40E64416C49BCE4540E62329E961F80E403FB8F1DD9CCE454035B401D880F80E409787F13F9ECE4540DC7AF25597F80E40C68F8C30A0CE45406E50FBAD9DF80E40D798219FA1CE4540DC7AF25597F80E404CBD1358A5CE4540	w108362035	108362035	way	footway	\N	\N	\N	\N
19	0102000020E610000002000000DB7FAEC78EF70E40090D0E40B4CE45406E9A88C8FAF70E40F678C663ABCE4540	w108362038	108362038	way	footway	\N	\N	\N	\N
20	0102000020E610000006000000EAC083B064F80E40D0CF7932A4CE4540BEDBBC7152F80E40C3D9081FA5CE45401715CCF33BF80E4040C7A244A6CE454081A268D432F80E40332D5679A7CE454006C13E952EF80E405C8C26BCA9CE45404DA3C9C518F80E40674815C5ABCE4540	w108362040	108362040	way	footway	\N	\N	\N	\N
21	0102000020E61000000400000056C2C9ECE2FC0E407EC3E9C9A1CE45400E2CEC0ECEFC0E40C042E6CAA0CE4540540E773FB8FC0E403DAC81F79FCE45402D6F586485FC0E40F6132928A0CE4540	w110450300	110450300	way	footway	\N	\N	\N	\N
22	0102000020E6100000040000006E50FBAD9DF80E40D798219FA1CE45409BEE2BC544F90E409BB1C3F3ADCE454026CA390C41F90E4001B4F7F3B7CE45401B50CAFF3FF90E404D17BDAEBACE4540	w110450301	110450301	way	footway	\N	\N	\N	\N
23	0102000020E61000000300000083047B0217FA0E40C330BB82C8CE454006E3964517FA0E40ACAC6D8AC7CE4540B9E92A3817FA0E402B508BC1C3CE4540	w110450302	110450302	way	footway	\N	\N	\N	\N
24	0102000020E610000002000000B699AF37D6FA0E40F956DA988DCE4540AD8905BEA2FB0E40B6A3930090CE4540	w123899952	123899952	way	footway	\N	\N	\N	\N
25	0102000020E61000000200000011209E8081FB0E40F1FDC34C91CE454060FF1AB567FB0E40F928C8748DCE4540	w123899953	123899953	way	footway	\N	\N	\N	\N
26	0102000020E610000008000000B185C54DB2FA0E4073FB404D88CE454000169E3CD1FA0E4061342BDB87CE4540A6D997C7F5FA0E4073FB404D88CE4540CC1E0D4C13FB0E404FF1136289CE4540C9BE750F1AFB0E406BBCCF4C8BCE454019BECF02FEFA0E4070E998F38CCE4540B699AF37D6FA0E40F956DA988DCE4540EBB01DE791FA0E4059A7CAF78CCE4540	w123899954	123899954	way	footway	\N	\N	\N	\N
27	0102000020E610000002000000F46679C322FB0E4087365BD482CE45405749BFD8D6FA0E408DC5803683CE4540	w123899955	123899955	way	footway	\N	\N	\N	\N
28	0102000020E61000000200000050A15F0086FA0E40A5D93C0E83CE45405749BFD8D6FA0E408DC5803683CE4540	w123899956	123899956	way	steps	\N	\N	\N	\N
29	0102000020E610000003000000EBB01DE791FA0E4059A7CAF78CCE4540B185C54DB2FA0E4073FB404D88CE45405CE91093CBFA0E40D4E1D7FE84CE4540	w123899957	123899957	way	footway	\N	\N	\N	\N
30	0102000020E6100000020000009C7F057AF2FA0E40F5FEF5C07DCE45405749BFD8D6FA0E408DC5803683CE4540	w123899958	123899958	way	footway	\N	\N	\N	\N
31	0102000020E610000002000000B41204D9FCF90E40DA22C4F06CCE4540ABBB687EEBF90E40EBB58FCB6ECE4540	w123899959	123899959	way	steps	\N	\N	\N	\N
32	0102000020E610000003000000C8748D3B4AFA0E40981991836DCE45409886E12362FA0E40E5DEB2F96ECE45405CE102756FFA0E402580513871CE4540	w123899960	123899960	way	steps	\N	\N	\N	\N
33	0102000020E61000000500000050A15F0086FA0E40A5D93C0E83CE45407C8B3D6A02FB0E40DA8AA2AC84CE45404C9D91521AFB0E40AA4885B185CE454074E5FDC929FB0E404435255987CE454060FF1AB567FB0E40F928C8748DCE4540	w123899961	123899961	way	footway	\N	\N	\N	\N
34	0102000020E61000000A0000008DDA58E432F90E407EAB75E272CE4540C6617A0CA0F90E40A964A5EE6FCE4540ABBB687EEBF90E40EBB58FCB6ECE4540AB4CE77926FA0E405C85DE2C6FCE45405CE102756FFA0E402580513871CE45400762348694FA0E40D67A754474CE4540F321A81ABDFA0E408789062978CE45409C7F057AF2FA0E40F5FEF5C07DCE4540F46679C322FB0E4087365BD482CE45408541994693FB0E405EC026C68DCE4540	w123899962	123899962	way	footway	\N	\N	\N	\N
35	0102000020E6100000020000005CE91093CBFA0E40D4E1D7FE84CE45405749BFD8D6FA0E408DC5803683CE4540	w123899963	123899963	way	footway	\N	\N	\N	\N
36	0102000020E6100000020000005CE91093CBFA0E40D4E1D7FE84CE454050A15F0086FA0E40A5D93C0E83CE4540	w123899964	123899964	way	steps	\N	\N	\N	\N
37	0102000020E610000002000000FBF48E09E7F90E401C77EF4D78CE4540A22A018CC2F90E4071A4D8767FCE4540	w153318870	153318870	way	footway	\N	\N	\N	\N
38	0102000020E610000002000000FBF48E09E7F90E401C77EF4D78CE4540883A62E3B0FA0E4044D6BF907ACE4540	w153318871	153318871	way	footway	\N	\N	\N	\N
39	0102000020E61000000600000087B13B93ECF70E40AEB195E189CE4540BBCDC06D12F80E40332C90EA85CE454062BEBC00FBF80E4008BB174E88CE45403C6C7DEC89F90E4072231BFE89CE454039888CFD1BFA0E404DD136A38BCE4540EBB01DE791FA0E4059A7CAF78CCE4540	w153318872	153318872	way	footway	\N	\N	\N	\N
40	0102000020E610000002000000A0C552245FF90E4088BD50C076CE4540829DAC623BF90E400DCBFA287ECE4540	w153318873	153318873	way	footway	\N	\N	\N	\N
41	0102000020E610000002000000FBF48E09E7F90E401C77EF4D78CE4540A0C552245FF90E4088BD50C076CE4540	w153318874	153318874	way	footway	\N	\N	\N	\N
42	0102000020E610000003000000D9BBF55091F90E409C0425BB88CE4540727B38375CFA0E40F415A4198BCE454050A15F0086FA0E40A5D93C0E83CE4540	w153318875	153318875	way	footway	\N	\N	\N	\N
43	0102000020E610000003000000883A62E3B0FA0E4044D6BF907ACE454050A15F0086FA0E40A5D93C0E83CE4540DDEEE53E39FA0E40F3BE3B4382CE4540	w153318876	153318876	way	footway	\N	\N	\N	\N
44	0102000020E610000002000000D9BBF55091F90E409C0425BB88CE4540AB37B41204F90E40FC12961D87CE4540	w153318877	153318877	way	footway	\N	\N	\N	\N
45	0102000020E61000000200000062BEBC00FBF80E4008BB174E88CE4540AB37B41204F90E40FC12961D87CE4540	w153318878	153318878	way	footway	\N	\N	\N	\N
46	0102000020E6100000030000003C6C7DEC89F90E4072231BFE89CE4540D9BBF55091F90E409C0425BB88CE454056348C71B4F90E40E7FC14C781CE4540	w153318880	153318880	way	footway	\N	\N	\N	\N
47	0102000020E6100000150000007C592437D4F90E4083C7123180CE4540E9633E20D0F90E408970DDDE7FCE4540DA6C510BCAF90E40C5D0459E7FCE4540A22A018CC2F90E4071A4D8767FCE4540E24C5D43BAF90E404E2A1A6B7FCE4540BD619115B2F90E40AD60657E7FCE454008FE5CD9AAF90E40D10836AE7FCE4540B1CA3B3DA5F90E403CA583F57FCE4540BF8465C7A1F90E404739984D80CE45409CF639E3A0F90E408F8939AD80CE45404820B990A2F90E40AC5A2D0B81CE4540280F0BB5A6F90E40D030105F81CE454084FF63D7ACF90E4094D0A79F81CE454056348C71B4F90E40E7FC14C781CE4540171230BABCF90E40E1F725D181CE4540EF0390DAC4F90E4082C1DABD81CE4540A367C416CCF90E40CA59338D81CE4540ADA179A5D1F90E405FBDE54581CE454052EEE30DD5F90E405329D1ED80CE45402783A3E4D5F90E40A098068F80CE45407C592437D4F90E4083C7123180CE4540	w201375990	201375990	way	footway	\N	\N	\N	\N
48	0102000020E610000002000000845B881FADFB0E40ABD0402C9BCE4540D027F224E9FA0E40CF98EE1A99CE4540	w201375993	201375993	way	footway	\N	\N	\N	\N
49	0102000020E61000000D0000009EF419AB28F90E40721AA20A7FCE4540EF6A03C12DF90E4036A6CC727ECE4540D3F6AFAC34F90E4013FEFB427ECE4540829DAC623BF90E400DCBFA287ECE4540DB2D6E4848F90E4060F767507ECE4540C0B91A344FF90E40B956D6917ECE4540FA3B253152F90E4054A5D2F47ECE4540A785819D51F90E4048F718517FCE4540750069A44AF90E4053B93FCD7FCE454093D453F53CF90E40899EEF0280CE4540BE22AE5230F90E40BFF968CC7FCE4540B5E8F8C32AF90E405A620A7B7FCE45409EF419AB28F90E40721AA20A7FCE4540	w201375995	201375995	way	footway	\N	\N	\N	\N
50	0102000020E61000000B0000008D5E0D501AFA0E404C384FD081CE45406C2D82B520FA0E4041A43A7881CE45407D810F142EFA0E40B8EE416381CE4540E4CBFA8337FA0E402FC37FBA81CE4540DDEEE53E39FA0E40F3BE3B4382CE4540C83AC1A332FA0E4070C67AB482CE4540C360A35126FA0E40C9F7D6D182CE454014BAA69B1FFA0E40F34872AF82CE4540E6D1E8691BFA0E40BD63C27982CE454035EB313619FA0E40E7864B3382CE45408D5E0D501AFA0E404C384FD081CE4540	w237196759	237196759	way	footway	\N	\N	\N	\N
51	0102000020E610000002000000BF8465C7A1F90E404739984D80CE4540A785819D51F90E4048F718517FCE4540	w237196761	237196761	way	footway	\N	\N	\N	\N
52	0102000020E61000000200000052EEE30DD5F90E405329D1ED80CE45408D5E0D501AFA0E404C384FD081CE4540	w237196762	237196762	way	footway	\N	\N	\N	\N
53	0102000020E610000002000000AB37B41204F90E40FC12961D87CE4540BE22AE5230F90E40BFF968CC7FCE4540	w237196764	237196764	way	footway	\N	\N	\N	\N
54	0102000020E6100000030000009EF419AB28F90E40721AA20A7FCE4540996780666BF80E404FC0C0BD7CCE45404F7C105DABF80E4057D11F9A79CE4540	w237196766	237196766	way	footway	\N	\N	\N	\N
55	0102000020E610000002000000D027F224E9FA0E40CF98EE1A99CE4540A665FF97C6FA0E40C404DAC298CE4540	w237199066	237199066	way	steps	\N	\N	\N	\N
56	0102000020E610000002000000A665FF97C6FA0E40C404DAC298CE4540493B246BC3F70E40860552BD90CE4540	w237199067	237199067	way	footway	\N	\N	\N	\N
57	0102000020E6100000020000005BF6DA221FFA0E40DDC36F54B8CE454026CA390C41F90E4001B4F7F3B7CE4540	w280302698	280302698	way	footway	\N	\N	\N	\N
58	0102000020E6100000050000008170AA5A77F80E403579CA6ABACE454000CF51A280F80E400158D3ABB7CE4540D5BAC3DCA4F80E400955C5AFB3CE45402FA52E19C7F80E40359E639BAFCE45409BC937DBDCF80E40123E4ADBAECE4540	w280302700	280302700	way	footway	\N	\N	\N	\N
59	0102000020E6100000040000003D5A417859F80E40B99C5C9DADCE4540F5CB71B8A0F80E40EE9579ABAECE45409BC937DBDCF80E40123E4ADBAECE45409BEE2BC544F90E409BB1C3F3ADCE4540	w280302701	280302701	way	footway	\N	\N	\N	\N
60	0102000020E610000004000000FC5C2338E4F50E402920ED7F80CE4540A4E9471EE3F50E4058B2BEDC82CE45403B996EC8F5F50E40F669CB6F87CE45404249DCBEA2F60E407AE1CE8591CE4540	w575119855	575119855	way	footway	\N	\N	\N	\N
61	0102000020E610000008000000266195C107F50E400F95EB127ACE45401FBE4C1421F50E4002CD8C237BCE4540181B04673AF50E409D77ADCE7BCE454068AED3484BF50E401F0E12A27CCE4540C4BB12375DF50E40FB03E5B67DCE45404EB10F5773F50E40FA87E3AF7FCE4540A4E9471EE3F50E4058B2BEDC82CE4540915D0E6036F60E406254089A85CE4540	w575119856	575119856	way	footway	\N	\N	\N	\N
62	0102000020E61000000300000017FB8161AFF60E40DA65097C8FCE4540A4E9471EE3F50E4058B2BEDC82CE4540E2523AFD45F50E40EC06C02E79CE4540	w575119857	575119857	way	footway	\N	\N	\N	\N
63	0102000020E610000004000000CB78A576D0F60E401271CEE38BCE454017FB8161AFF60E40DA65097C8FCE45404249DCBEA2F60E407AE1CE8591CE4540D421DC099BF60E40E4A5F67D93CE4540	w575119858	575119858	way	footway	\N	\N	\N	\N
64	0102000020E610000006000000713C9F01F5F60E40DFE57D7786CE45406504AFF1F4F50E40E60709AC77CE4540E4486760E4F50E401C075E2D77CE4540CABA2473D1F50E40C964277277CE454035B742588DF50E408022BB7779CE45404134A95780F50E40626534F279CE4540	w575119859	575119859	way	footway	Allée des Platanes	\N	\N	\N
65	0102000020E61000000A0000000B968F49EBF40E40C181DAB97ACE45406A036674F6F40E4056E58C727ACE4540266195C107F50E400F95EB127ACE4540E2523AFD45F50E40EC06C02E79CE454003DB77FB62F50E40D43ABBC678CE45404134A95780F50E40626534F279CE4540FC5C2338E4F50E402920ED7F80CE454079D5B95807F60E40BDBFE6C182CE4540915D0E6036F60E406254089A85CE454032F8455387F60E40D1E39C7D8ACE4540	w575119860	575119860	way	footway	Allée Centrale	\N	\N	\N
66	0102000020E61000000700000032F8455387F60E40D1E39C7D8ACE4540BC2A06FEA6F60E4000AAB8718BCE4540CB78A576D0F60E401271CEE38BCE45401C0C7558E1F60E407E13549E8ACE45406C9F443AF2F60E406C0ABF2F89CE4540C76FC09DFAF60E40DE550F9887CE4540713C9F01F5F60E40DFE57D7786CE4540	w575119861	575119861	way	footway	\N	\N	\N	\N
67	0102000020E610000002000000D0413CB775FC0E4061264003A0CE4540E8FE452B52FC0E405B69087D9FCE4540	w579006095	579006095	way	steps	\N	\N	\N	\N
68	0102000020E6100000030000007FF0468BD8FC0E406306CF296DCE45401323F02CE6FC0E40FDAAB7616FCE454029F7F186EAFC0E40FCEC365E70CE4540	w683777446	683777446	way	footway	\N	\N	\N	\N
69	0102000020E610000003000000A0956A5501FD0E40BF38A74874CE4540ED8ED66201FD0E400234A55071CE4540D9DAB1C7FAFC0E409783EA3070CE4540	w683777489	683777489	way	footway	\N	\N	no	sett
70	0102000020E610000004000000A8B3493437F50E40C108D0A56ECE45409559CEEF45F50E40B09DDE7B6ECE454081DFD0A5C9F60E40BE439B2D6ACE4540534EC5D7E8F60E401DF0AFD469CE4540	w719462960	719462960	way	footway	Place Jacques Mirouze	\N	\N	\N
71	0102000020E610000009000000067C235FAEFA0E40FF29B05B5FCE4540C539EAE8B8FA0E405E32E94A5FCE45404A928C41CCFA0E407041B62C5FCE45407B88467710FB0E40A1A6F16668CE45407E05C47F15FB0E40DC1AC7FE68CE4540816A72E778FB0E40FA50589874CE4540D0C07E3E80FB0E4023E4727275CE454015AD37C53EFC0E40BFC8152873CE4540A885371037FC0E40EF38454772CE4540	w805354151	805354151	way	footway	\N	\N	\N	\N
\.


--
-- Data for Name: gardens; Type: TABLE DATA; Schema: pgmetadata_demo; Owner: -
--

COPY pgmetadata_demo.gardens (id, geom, full_id, osm_id, osm_type, leisure, name, landuse, wikipedia) FROM stdin;
1	0106000020E6100000010000000103000000010000001C0000009FEF5D3931FA0E40FB67BC6367CE4540B9CC446C0BFA0E40A1C096B267CE45402FBA6180E9F90E409BA1027168CE4540B7DE2527C9F90E40A6ED5F5969CE4540C0C12852ABF90E40B295E1896ACE45406851E97129F80E405A208B7E7ECE454011A2218898F70E40AF3610DC92CE4540D382BCC392F70E40CB15399F95CE45400A14B18861F70E40619C09979FCE4540542CC8E072F60E40C7736CF3B5CE4540909CF122B8F60E40CB587E2AB8CE45404B146B0256F80E409A9DA0A8C7CE454006E3964517FA0E40ACAC6D8AC7CE45409F19694E03FB0E4070F0E082C7CE4540B5ED6AA807FB0E4020240B98C0CE45401D7D27C176FB0E409E45EF54C0CE45401E296C5045FB0E405D6DC5FEB2CE4540FA5D7DE13AFB0E401DB8B9E7AFCE45406F6589CE32FB0E40122ADD02AECE45401F8315A75AFB0E402E8AC33EA6CE45400FC3FD367AFB0E40EADB3818A0CE45401A52A0AA9DFC0E40F4D9A61DA3CE45402D6F586485FC0E40F6132928A0CE454095117239B9FA0E40DB560E886BCE4540CE39D3DFA6FA0E40E894360B6ACE45401DFC694881FA0E4030BDFDB968CE454007B1D8CB5BFA0E40F5BEF1B567CE45409FEF5D3931FA0E40FB67BC6367CE4540	w8105305	8105305	way	park	Jardin des Plantes	\N	fr:Jardin des plantes de Montpellier
2	0106000020E6100000010000000103000000010000000F00000082D6B26B31FE0E40D3A5DA029DCE4540413DC79118FE0E40A29CC31094CE4540844B2256DAFD0E40021BC69393CE4540FB1B599EACFD0E40DE16D11B93CE4540557545DF93FD0E40EB96789B92CE454024F323D97EFD0E40BBFE6ECB91CE4540D23F773870FD0E4021F829D890CE4540470AC09A5EFD0E409315681C8FCE4540457353B93FFD0E4028A72CF98ECE4540DB2F44F3A5FC0E400397C79A91CE4540F994AD3FD3FC0E40A1D80A9A96CE45401203136EE8FC0E40BE2DFDF098CE45403CFFD19222FD0E40F0FACC599FCE45402425E2523AFD0E40C63368E89FCE454082D6B26B31FE0E40D3A5DA029DCE4540	w78195773	78195773	way	park	Square de la Tour des Pins	\N	\N
3	0106000020E61000000100000001030000000100000012000000F32F93F2A4F60E4061376C5B94CE4540B3F0506FA1F60E405B608F8994CE4540F1D2F2A89DF60E4078D55E9F94CE4540233B25D698F60E403714E3A194CE454008AAEBF593F60E406D9D6E8F94CE4540F2D5E99B8FF60E409CF3F86294CE454077F4BF5C8BF60E4043948A2194CE4540A6DF748181F60E402667727B93CE45406A036674F6F40E4056E58C727ACE4540272AC01CE2F40E40758EA61F79CE4540D98C1D9E6FF50E40E7C589AF76CE4540B9BD4978E7F50E40A7C8C62874CE4540EEF9AB110BF60E40527C7C4276CE4540C98A86318EF60E4066A032FE7DCE45402CAFA6FCB5F60E404106973380CE45405FB35C363AF70E40143BBFCD87CE45400E524BCEE4F60E40F984ECBC8DCE4540F32F93F2A4F60E4061376C5B94CE4540	w116984605	116984605	way	park	Jardin de la Reine	\N	\N
4	0106000020E61000000100000001030000000100000016000000695B28F455FD0E40FEFEDEB76BCE4540568D148035FD0E40E9CEB81567CE454016F71F990EFD0E407554DA8761CE4540435376FA41FD0E40D51A947A60CE454053C1F23169FD0E40467A51BB5FCE45407586F3BA8FFD0E404161F5EC5ECE4540F01D90DF36FE0E40DD312BCA5BCE454055826A285AFE0E40AB11B00C60CE4540F37D271C30FE0E405D120C8C61CE45409DF3531C07FE0E4003DB77FB62CE45406A317898F6FD0E4056911B8F63CE4540996EC8F5A5FD0E402535594865CE45403C5E9214A2FD0E4091BD39B764CE454034ED07E176FD0E401A2B7B5C65CE45406B0F7BA180FD0E40BFF3E6CB66CE4540ADAB5D6E8BFD0E40D707A3A366CE4540E17030E58DFD0E40B3171B0467CE4540F4215E8DA2FD0E40F57C72B966CE45400353173AC0FD0E40DB9EC5F76ACE45405232946EA6FD0E40A5715E526BCE4540D8FCAEBE70FD0E4010E099756BCE4540695B28F455FD0E40FEFEDEB76BCE4540	w535256105	535256105	way	garden	\N	\N	\N
5	0106000020E6100000010000000103000000010000000C0000009DF3531C07FE0E4003DB77FB62CE45402149FF8128FE0E40019BBD7D67CE4540C8F2093433FE0E4024E131F268CE4540DBA337DC47FE0E40CA81C3B068CE45406FD6E07D55FE0E40E89A6E7E68CE45401C203DEA54FE0E4077CB1F1D68CE4540B96FB54E5CFE0E406CDBE67C67CE454038EE395563FE0E409C31715067CE4540ACD568835DFE0E404F52AA8E66CE45400292FAFC41FE0E40EB50F28F63CE4540F37D271C30FE0E405D120C8C61CE45409DF3531C07FE0E4003DB77FB62CE4540	w535256106	535256106	way	garden	\N	\N	\N
6	0106000020E6100000010000000103000000010000000D0000003A4668BA8DFC0E409824856863CE454046C0D7C68EFC0E40A919ADFE63CE4540A3B327DC86FC0E403830B95164CE4540CC1363F437FC0E40BFD9418067CE4540D770EC342DFC0E404EF04DD367CE4540BC8800F104FC0E40B36D07D968CE4540A5B107A40EFC0E401D4CD41C6ACE454094D1127530FC0E40DC0022B369CE45404B75012F33FC0E40888CFD1B6ACE4540568D148035FD0E40E9CEB81567CE454016F71F990EFD0E407554DA8761CE454073E26190AAFC0E4044CA051D63CE45403A4668BA8DFC0E409824856863CE4540	w535256112	535256112	way	garden	\N	\N	\N
\.


--
-- Data for Name: trees; Type: TABLE DATA; Schema: pgmetadata_demo; Owner: -
--

COPY pgmetadata_demo.trees (id, geom, full_id, osm_id, osm_type, height, leaf_type, genus) FROM stdin;
1	0101000020E6100000522AE109BDFE0E407B50AB43C9CE4540	n2780932669	2780932669	node	\N	broadleaved	Platanus
2	0101000020E610000041B96DDFA3FE0E40C9491751C9CE4540	n2780932670	2780932670	node	\N	broadleaved	Platanus
3	0101000020E610000061A010A6CDFD0E40EC7B1EEDC9CE4540	n2780954036	2780954036	node	\N	broadleaved	Platanus
4	0101000020E6100000A968ACFD9DFD0E401585025BCACE4540	n2780954040	2780954040	node	\N	broadleaved	Platanus
5	0101000020E6100000C328AD646CFD0E40211917B3CACE4540	n2780954043	2780954043	node	\N	broadleaved	Platanus
6	0101000020E6100000C30BC79860FD0E40857D96427BCE4540	n2826684794	2826684794	node	8	needleleaved	Cupressus
7	0101000020E6100000C1E3DBBB06FD0E4085ABA8667BCE4540	n2826684795	2826684795	node	8	needleleaved	Cupressus
8	0101000020E6100000F6B0BC5065FD0E40B323D5777ECE4540	n2826686908	2826686908	node	8	needleleaved	Cupressus
9	0101000020E61000006D0D5B6908FD0E401EC022BF7ECE4540	n2826686909	2826686909	node	8	needleleaved	Cupressus
10	0101000020E6100000C4FAF5F9DEF50E4022D5C10B6CCE4540	n3888012868	3888012868	node	\N	\N	\N
11	0101000020E6100000A663CE33F6F50E407677F8C66BCE4540	n3888012869	3888012869	node	\N	\N	\N
12	0101000020E6100000060E68E90AF60E40409248916BCE4540	n3888012870	3888012870	node	\N	\N	\N
13	0101000020E610000012C2A38D23F60E4088FC8E3C6BCE4540	n3888012871	3888012871	node	\N	\N	\N
14	0101000020E61000006E9516E41DF60E40FF04172B6ACE4540	n3888012872	3888012872	node	\N	\N	\N
15	0101000020E6100000050B71F618F60E40D03EFB3669CE4540	n3888012873	3888012873	node	\N	\N	\N
16	0101000020E610000098E3704111F60E40D1FC7B3A68CE4540	n3888012874	3888012874	node	\N	\N	\N
17	0101000020E6100000D34B8C65FAF50E4059E0867368CE4540	n3888012875	3888012875	node	\N	\N	\N
18	0101000020E610000055D0FE51E5F50E40EEFB81BC68CE4540	n3888012876	3888012876	node	\N	\N	\N
19	0101000020E6100000559632BACDF50E405393E00D69CE4540	n3888012877	3888012877	node	\N	\N	\N
20	0101000020E6100000BE20D8A7D2F50E405FDF3DF669CE4540	n3888012878	3888012878	node	\N	\N	\N
21	0101000020E610000027AB7D95D7F50E403AD5100B6BCE4540	n3888012879	3888012879	node	\N	\N	\N
22	0101000020E6100000CE716E13EEF50E40B2F105D26ACE4540	n3888012880	3888012880	node	\N	\N	\N
23	0101000020E6100000D925AAB706F60E40649C757C6ACE4540	n3888012881	3888012881	node	\N	\N	\N
24	0101000020E6100000709B04CA01F60E404D18288469CE4540	n3888012882	3888012882	node	\N	\N	\N
25	0101000020E61000005A6D5919E8F50E408E35C8C969CE4540	n3888012883	3888012883	node	\N	\N	\N
26	0101000020E61000007BEC78DD6CFD0E401895D40968CE4540	n5188660136	5188660136	node	\N	\N	\N
27	0101000020E610000056116E32AAFC0E40C5B01E5267CE4540	n5188660137	5188660137	node	\N	\N	\N
28	0101000020E610000091CB248F4CFC0E40CA95308969CE4540	n5188660140	5188660140	node	\N	\N	\N
29	0101000020E610000008C4904193F90E40EF0A332372CE4540	n8985917553	8985917553	node	\N	\N	\N
30	0101000020E6100000384BC97212FA0E40139F967A71CE4540	n8985917554	8985917554	node	\N	\N	\N
31	0101000020E6100000D7A546E867FA0E408E38094A76CE4540	n8985917555	8985917555	node	\N	\N	\N
32	0101000020E6100000C6AB0727FDF80E4074A213F879CE4540	n8985917556	8985917556	node	\N	\N	\N
33	0101000020E6100000F30F11ED19F80E4082CD943199CE4540	n8985917557	8985917557	node	\N	\N	\N
34	0101000020E6100000E6971CD203FA0E40EF3B86C77ECE4540	n8985917558	8985917558	node	\N	\N	\N
35	0101000020E6100000BCF7263C57FA0E401887E93180CE4540	n8985917559	8985917559	node	\N	\N	\N
36	0101000020E6100000384BC97212FA0E409D499BAA7BCE4540	n8985917560	8985917560	node	\N	\N	\N
37	0101000020E6100000A9BD88B663FA0E40311DDF837CCE4540	n8985917561	8985917561	node	\N	\N	\N
38	0101000020E61000009E85F35FD6FA0E40C5D9BE918ACE4540	n8985917562	8985917562	node	\N	\N	\N
39	0101000020E6100000FD8BFBEA05FA0E40798A66AF88CE4540	n8985917563	8985917563	node	\N	\N	\N
40	0101000020E6100000A264CD23DAF90E40B66C08E984CE4540	n8985917564	8985917564	node	\N	\N	\N
41	0101000020E61000006A447A9B48FA0E40927C804985CE4540	n8985917565	8985917565	node	\N	\N	\N
42	0101000020E61000009555C7E017FD0E404DCF053FBBCE4540	n8985917566	8985917566	node	\N	\N	\N
43	0101000020E6100000A9E221E758F90E403F79B361A8CE4540	n8985917567	8985917567	node	\N	\N	\N
44	0101000020E6100000F393C55801F90E405310F230A3CE4540	n8985917568	8985917568	node	\N	\N	\N
45	0101000020E610000067CA98CCC2F80E4068EFE76F9DCE4540	n8985917569	8985917569	node	\N	\N	\N
46	0101000020E6100000A0C552245FF90E40256AB3FB9FCE4540	n8985917570	8985917570	node	\N	\N	\N
47	0101000020E610000063EBBE08BFF90E40C4978922A4CE4540	n8985917571	8985917571	node	\N	\N	\N
48	0101000020E61000002397491E99F80E409AAECC00BCCE4540	n8985917572	8985917572	node	\N	\N	\N
49	0101000020E6100000F393C55801F90E405729988CBECE4540	n8985917573	8985917573	node	\N	\N	\N
50	0101000020E6100000FAEC80EB8AF90E40C35554B3BDCE4540	n8985917574	8985917574	node	\N	\N	\N
51	0101000020E610000067A5FF9BCDF90E40B9122631ADCE4540	n8985917575	8985917575	node	\N	\N	\N
52	0101000020E6100000CA8AE1EA00F80E402F51BD35B0CE4540	n8985917576	8985917576	node	\N	\N	\N
53	0101000020E6100000F7C9518028F80E406D4AC33A9FCE4540	n8985917577	8985917577	node	\N	\N	\N
54	0101000020E6100000D5C276418EF70E40253FE257ACCE4540	n8985917578	8985917578	node	\N	\N	\N
55	0101000020E610000004C6FA0626F70E40A07C30DFB0CE4540	n8985917579	8985917579	node	\N	\N	\N
56	0101000020E6100000A264CD23DAF90E40CD7E935CB4CE4540	n8985917580	8985917580	node	\N	\N	\N
57	0101000020E610000035289A07B0F80E408FB05EFBB8CE4540	n8985917581	8985917581	node	\N	\N	\N
58	0101000020E610000048C153C895FA0E40D266E613C3CE4540	n8985917582	8985917582	node	\N	\N	\N
59	0101000020E61000005698631E9EFA0E402EDE3422BDCE4540	n8985917583	8985917583	node	\N	\N	\N
60	0101000020E6100000C70A2362EFFA0E40E3885A3FA2CE4540	n8985917584	8985917584	node	\N	\N	\N
61	0101000020E610000067A5FF9BCDF90E406D4AC33A9FCE4540	n8985917585	8985917585	node	\N	\N	\N
62	0101000020E610000089D1730B5DF90E40FE4C182884CE4540	n8985917586	8985917586	node	\N	\N	\N
63	0101000020E61000001FB86F5A95F90E40C139234A7BCE4540	n8985917587	8985917587	node	\N	\N	\N
64	0101000020E6100000F390291F82FA0E40794375CEAACE4540	n8985917588	8985917588	node	\N	\N	\N
65	0101000020E6100000261EABEF57FC0E40C8D2872EA8CE4540	n8985917589	8985917589	node	\N	\N	\N
66	0101000020E6100000DB221FAADFFB0E4032B15472A9CE4540	n8985917590	8985917590	node	\N	\N	\N
67	0101000020E61000003CFFD19222FD0E4044520B2593CE4540	n8985917591	8985917591	node	\N	\N	\N
68	0101000020E6100000F0D69EFE58FD0E408F11F52796CE4540	n8985917592	8985917592	node	\N	\N	\N
69	0101000020E6100000598638D6C5FD0E400AF31E679ACE4540	n8985917593	8985917593	node	\N	\N	\N
\.


--
-- Data for Name: water_surfaces; Type: TABLE DATA; Schema: pgmetadata_demo; Owner: -
--

COPY pgmetadata_demo.water_surfaces (id, geom, full_id, osm_id, osm_type, "natural", landuse) FROM stdin;
1	0106000020E6100000010000000103000000010000000B0000006F415B73ECF50E4030A990E167CE45401F91A5C5CFF50E40C596790668CE4540D19739B8CFF50E40A1EEA8D667CE4540043D2F70D4F50E408FB1C9D067CE45407EE19524CFF50E406724E76965CE4540220E23CED4F50E406724E76965CE4540B863A021D2F50E40A919ADFE63CE454029CE5147C7F50E4038D4940964CE4540EAAEEC82C1F50E409972744B61CE45403B5FA230DEF50E4069C0C52F61CE45406F415B73ECF50E4030A990E167CE4540	w75781304	75781304	way	\N	basin
2	0106000020E6100000010000000103000000010000002C00000086B652BE56F80E40111B2C9CA4CE4540AB47759549F80E406AD6BE25A5CE454007FE012038F80E40642DF477A5CE45408505F7031EF80E4005F7A864A5CE4540637AC2120FF80E40F38BB73AA5CE4540ACB9ED8C00F80E4082EA7AFDA4CE4540E95ECC3BF3F70E4041CDDAB7A4CE454014B01D8CD8F70E409A740069A4CE4540B2E5A617C6F70E40F9AA4B7CA4CE4540ABCBCE47BEF70E40232AF97DA4CE454000C22C59BAF70E400BE82A82A4CE4540E1B37570B0F70E400B163DA6A4CE45404344204DABF70E40644799C3A4CE4540E873A4E9A2F70E40C3071B43A5CE4540734FB2309FF70E40FFF1B96EA5CE45408DA328869AF70E40EDE2EC8CA5CE4540A23A675595F70E40EDE2EC8CA5CE4540B6D1A52490F70E40226C787AA5CE45405F7EA7C98CF70E40E17CEA58A5CE45407D6F78E68AF70E4023105432A5CE4540072BA96E89F70E40FF678302A5CE454072F508DA89F70E404600DCD1A4CE4540B91160A28BF70E40D6308D70A4CE4540757286E28EF70E4065613E0FA4CE45400E25A47F93F70E40710FF8B2A3CE4540CF22258799F70E40CAB61D64A3CE45405D9896A2A6F70E40C427F801A3CE454084DD0B27C4F70E4000FE2955A2CE45401270630EDDF70E4018E4D308A2CE4540F2B5679604F80E409B0AA7BBA1CE4540346F302F1BF80E40E3D011AFA1CE45407BC84A8226F80E4030CA7DBCA1CE45407BE5304E32F80E40607C2CD8A1CE4540C33E4BA13DF80E406CE22E0CA2CE45403403A61D48F80E40D1798D5DA2CE454077BF65A950F80E4018CA2EBDA2CE4540CF12640454F80E403C72FFECA2CE4540D96CF65157F80E405915E126A3CE45400875914259F80E4077B8C260A3CE45407EB960BA5AF80E4011D9AC9FA3CE45403C3A64B95BF80E40ACF996DEA3CE454066A5A4E25AF80E40C4978922A4CE45408B53AD8559F80E405FB87361A4CE454086B652BE56F80E40111B2C9CA4CE4540	w75781407	75781407	way	\N	basin
3	0106000020E61000000100000001030000000100000010000000A10F3BF82EFA0E402E7BC84A82CE4540CC9A58E02BFA0E408EB1135E82CE4540D4974AE427FA0E408EB1135E82CE45408201840F25FA0E40EDB94C4D82CE4540A1F2542C23FA0E40BD079E3182CE45401857016322FA0E407C18101082CE45403628F5C022FA0E40CFE858EF81CE4540117AEC1D24FA0E400B77D3D281CE45405D537B6C26FA0E40ED0104BD81CE454002A0E5D429FA0E4088C6C9B381CE4540FAA2F3D02DFA0E4041005FC081CE4540E16E5A3A30FA0E4070B20DDC81CE4540EDE8C94631FA0E405EA340FA81CE454052F6F12B31FA0E405ED1521E82CE45407C61325530FA0E403A85A63682CE4540A10F3BF82EFA0E402E7BC84A82CE4540	w237196750	237196750	way	\N	basin
4	0106000020E61000000100000001030000000100000010000000E8267B95C6F90E40D6D9DA0C81CE45408C362273C0F90E402906483481CE4540841C4AA3B8F90E402906483481CE45402DE92807B3F90E40E816BA1281CE454006BEA25BAFF90E40B2310ADD80CE4540F486FBC8ADF90E409A93179980CE45403029E384AEF90E40D6F37F5880CE454099D36531B1F90E40778F222180CE4540E48C17C1B5F90E40652431F77FCE454094331477BCF90E4006EEE5E37FCE4540E9465854C4F90E400C21E7FD7FCE4540CFF2E1FEC8F90E404106973380CE454098ED540ACBF90E408928266F80CE4540FDFA7CEFCAF90E40F4C473B680CE454052D1FD41C9F90E40176D44E680CE4540E8267B95C6F90E40D6D9DA0C81CE4540	w237196752	237196752	way	\N	basin
5	0106000020E610000001000000010300000001000000100000008997A77345F90E40BF41203C7FCE4540B422C55B42F90E40B33742507FCE4540BC1FB75F3EF90E40B33742507FCE45406A89F08A3BF90E407D80A43E7FCE4540D7732DB539F90E40E38DCC237FCE454001DF6DDE38F90E400CDF67017FCE45401EB0613C39F90E4060AFB0E07ECE4540FA0159993AF90E409B3D2BC47ECE454093D453F53CF90E40138832AF7ECE4540EB27525040F90E40198D21A57ECE4540E32A604C44F90E4066868DB27ECE4540CAF6C6B546F90E40017965CD7ECE4540D57036C247F90E40EF6998EB7ECE45408877CAB447F90E40EF97AA0F7FCE454065E99ED046F90E40600BD5287FCE45408997A77345F90E40BF41203C7FCE4540	w237196754	237196754	way	\N	basin
6	0106000020E61000000100000001030000000100000010000000D05499733AFA0E403A8D599B6BCE4540923534AF34FA0E408DB9C6C26BCE45403088A3062EFA0E40F3F400CC6BCE454051B92EA127FA0E40AB0084B46BCE45409B351DA622FA0E40345A58816BCE4540499F56D11FFA0E405E7DE13A6BCE4540FCA5EAC31FFA0E40E1A3B4ED6ACE454065506D7022FA0E40760767A66ACE4540CEDA125E27FA0E40D5E18D716ACE454060B01BB62DFA0E40F92D3A596ACE4540C15DAC5E34FA0E40A02AF05F6ACE45404D767D303AFA0E405E9786866ACE454045798B2C3EFA0E4064F899C46ACE4540BCBD5AA43FFA0E40B75219106BCE45402E65CF543EFA0E409F6C6F5C6BCE4540D05499733AFA0E403A8D599B6BCE4540	w237196756	237196756	way	\N	basin
\.


--
-- Name: contact_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.contact_id_seq', 3, true);


--
-- Name: dataset_contact_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.dataset_contact_id_seq', 5, true);


--
-- Name: dataset_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.dataset_id_seq', 8, true);


--
-- Name: glossary_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.glossary_id_seq', 136, true);


--
-- Name: html_template_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.html_template_id_seq', 3, true);


--
-- Name: link_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.link_id_seq', 4, true);


--
-- Name: theme_id_seq; Type: SEQUENCE SET; Schema: pgmetadata; Owner: -
--

SELECT pg_catalog.setval('pgmetadata.theme_id_seq', 3, true);


--
-- Name: Buildings_id_seq; Type: SEQUENCE SET; Schema: pgmetadata_demo; Owner: -
--

SELECT pg_catalog.setval('pgmetadata_demo."Buildings_id_seq"', 188, true);


--
-- Name: Footways_id_seq; Type: SEQUENCE SET; Schema: pgmetadata_demo; Owner: -
--

SELECT pg_catalog.setval('pgmetadata_demo."Footways_id_seq"', 71, true);


--
-- Name: Gardens_id_seq; Type: SEQUENCE SET; Schema: pgmetadata_demo; Owner: -
--

SELECT pg_catalog.setval('pgmetadata_demo."Gardens_id_seq"', 6, true);


--
-- Name: Trees_id_seq; Type: SEQUENCE SET; Schema: pgmetadata_demo; Owner: -
--

SELECT pg_catalog.setval('pgmetadata_demo."Trees_id_seq"', 69, true);


--
-- Name: Water_surfaces_id_seq; Type: SEQUENCE SET; Schema: pgmetadata_demo; Owner: -
--

SELECT pg_catalog.setval('pgmetadata_demo."Water_surfaces_id_seq"', 6, true);


--
-- Name: contact contact_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: dataset_contact dataset_contact_fk_id_contact_fk_id_dataset_contact_role_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset_contact
    ADD CONSTRAINT dataset_contact_fk_id_contact_fk_id_dataset_contact_role_key UNIQUE (fk_id_contact, fk_id_dataset, contact_role);


--
-- Name: dataset_contact dataset_contact_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset_contact
    ADD CONSTRAINT dataset_contact_pkey PRIMARY KEY (id);


--
-- Name: dataset dataset_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset
    ADD CONSTRAINT dataset_pkey PRIMARY KEY (id);


--
-- Name: dataset dataset_table_name_schema_name_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset
    ADD CONSTRAINT dataset_table_name_schema_name_key UNIQUE (table_name, schema_name);


--
-- Name: dataset dataset_uid_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset
    ADD CONSTRAINT dataset_uid_key UNIQUE (uid);


--
-- Name: glossary glossary_field_code_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.glossary
    ADD CONSTRAINT glossary_field_code_key UNIQUE (field, code);


--
-- Name: glossary glossary_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.glossary
    ADD CONSTRAINT glossary_pkey PRIMARY KEY (id);


--
-- Name: html_template html_template_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.html_template
    ADD CONSTRAINT html_template_pkey PRIMARY KEY (id);


--
-- Name: html_template html_template_section_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.html_template
    ADD CONSTRAINT html_template_section_key UNIQUE (section);


--
-- Name: link link_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.link
    ADD CONSTRAINT link_pkey PRIMARY KEY (id);


--
-- Name: theme theme_code_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.theme
    ADD CONSTRAINT theme_code_key UNIQUE (code);


--
-- Name: theme theme_label_key; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.theme
    ADD CONSTRAINT theme_label_key UNIQUE (label);


--
-- Name: theme theme_pkey; Type: CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.theme
    ADD CONSTRAINT theme_pkey PRIMARY KEY (id);


--
-- Name: buildings Buildings_pkey; Type: CONSTRAINT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.buildings
    ADD CONSTRAINT "Buildings_pkey" PRIMARY KEY (id);


--
-- Name: footways Footways_pkey; Type: CONSTRAINT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.footways
    ADD CONSTRAINT "Footways_pkey" PRIMARY KEY (id);


--
-- Name: gardens Gardens_pkey; Type: CONSTRAINT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.gardens
    ADD CONSTRAINT "Gardens_pkey" PRIMARY KEY (id);


--
-- Name: trees Trees_pkey; Type: CONSTRAINT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.trees
    ADD CONSTRAINT "Trees_pkey" PRIMARY KEY (id);


--
-- Name: water_surfaces Water_surfaces_pkey; Type: CONSTRAINT; Schema: pgmetadata_demo; Owner: -
--

ALTER TABLE ONLY pgmetadata_demo.water_surfaces
    ADD CONSTRAINT "Water_surfaces_pkey" PRIMARY KEY (id);


--
-- Name: dataset_id_idx; Type: INDEX; Schema: pgmetadata; Owner: -
--

CREATE INDEX dataset_id_idx ON pgmetadata.dataset USING btree (id);


--
-- Name: glossary_id_idx; Type: INDEX; Schema: pgmetadata; Owner: -
--

CREATE INDEX glossary_id_idx ON pgmetadata.glossary USING btree (id);


--
-- Name: qgis_plugin_id_idx; Type: INDEX; Schema: pgmetadata; Owner: -
--

CREATE INDEX qgis_plugin_id_idx ON pgmetadata.qgis_plugin USING btree (id);


--
-- Name: dataset trg_calculate_fields_from_data; Type: TRIGGER; Schema: pgmetadata; Owner: -
--

CREATE TRIGGER trg_calculate_fields_from_data BEFORE INSERT OR UPDATE ON pgmetadata.dataset FOR EACH ROW EXECUTE FUNCTION pgmetadata.calculate_fields_from_data();


--
-- Name: dataset trg_update_table_comment_from_dataset; Type: TRIGGER; Schema: pgmetadata; Owner: -
--

CREATE TRIGGER trg_update_table_comment_from_dataset AFTER INSERT OR UPDATE ON pgmetadata.dataset FOR EACH ROW EXECUTE FUNCTION pgmetadata.update_table_comment_from_dataset();


--
-- Name: dataset_contact dataset_contact_fk_id_contact_fkey; Type: FK CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset_contact
    ADD CONSTRAINT dataset_contact_fk_id_contact_fkey FOREIGN KEY (fk_id_contact) REFERENCES pgmetadata.contact(id) ON DELETE RESTRICT;


--
-- Name: dataset_contact dataset_contact_fk_id_dataset_fkey; Type: FK CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.dataset_contact
    ADD CONSTRAINT dataset_contact_fk_id_dataset_fkey FOREIGN KEY (fk_id_dataset) REFERENCES pgmetadata.dataset(id) ON DELETE CASCADE;


--
-- Name: link link_fk_id_dataset_fkey; Type: FK CONSTRAINT; Schema: pgmetadata; Owner: -
--

ALTER TABLE ONLY pgmetadata.link
    ADD CONSTRAINT link_fk_id_dataset_fkey FOREIGN KEY (fk_id_dataset) REFERENCES pgmetadata.dataset(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--
