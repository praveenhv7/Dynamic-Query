/* Formatted on 4/15/2017 7:53:10 PM (QP5 v5.215.12089.38647) */
CREATE OR REPLACE PROCEDURE get_conference_details_dynamic (
   p_in_conference_name    VARCHAR2,
   p_in_journal_name       VARCHAR2,
   p_in_author_name        VARCHAR2,
   p_in_year               VARCHAR2,
   p_in_year_option        VARCHAR2,
   p_in_title              VARCHAR2,
   p_in_choice             VARCHAR2,
   p_in_number_of_pubs     NUMBER,
   p_in_number_of_jours    NUMBER,  
   p_in_nums               NUMBER,
   p_in_min_pg             NUMBER,
   p_in_max_pg             NUMBER,
   p_out_error_message  OUT       VARCHAR2)
IS
   p_sql_pubs_stmt    VARCHAR2 (5000);
   p_sql_jors_stmt    VARCHAR2 (5000);
   p_from_tables      VARCHAR2 (500);
   p_sql_final_stmt   VARCHAR2 (10000);
   no_options_enabled EXCEPTION;
   p_dual_set         NUMBER;

   p_alias_set        VARCHAR2 (4);
BEGIN
   p_dual_set := 0;



   IF (p_in_author_name IS NULL)
   THEN
      CASE
         WHEN     p_in_conference_name IS NOT NULL
              AND p_in_journal_name IS NOT NULL
         THEN
            p_dual_set := 1;
         WHEN p_in_conference_name IS NOT NULL AND p_in_journal_name IS NULL
         THEN
            p_dual_set := 0;
            p_alias_set := 'pub';
         WHEN p_in_conference_name IS NULL AND p_in_journal_name IS NOT NULL
         THEN
            p_dual_set := 0;
            p_alias_set := 'jor';
         WHEN p_in_title IS NOT NULL OR p_in_year IS NOT NULL
         THEN
            p_dual_set := 1;
          ELSE
            raise no_options_enabled;
      END CASE;
   ELSE
      p_dual_set := 1;
   END IF;


   DBMS_OUTPUT.PUT_LINE (
      'p_alias_set ' || p_alias_set || ' p_dual_set ' || p_dual_set);

   IF (p_in_choice = 'OR')
   THEN
      SELECT    'select pub.author from PUBLICATIONS_SUBSET pub
              where 1=1 AND '
             || CASE
                   WHEN p_dual_set = 0 AND p_alias_set = 'pub'
                   THEN
                      'pub.booktitle in (''' || p_in_conference_name || ''')'
                   WHEN p_dual_set = 1
                   THEN
                      'pub.booktitle in (''' || p_in_conference_name || ''')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || CASE
                   WHEN p_alias_set = 'pub' AND p_in_title IS NOT NULL
                   THEN
                         'UPPER(pub.TITLE) LIKE UPPER(''%'
                      || p_in_title
                      || '%'')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || DECODE (
                   p_in_year_option,
                   NULL, '1=1',
                   'EQ', 'TO_NUMBER(pub.YEAR) = ' || TO_NUMBER (p_in_year),
                   'GEQ', 'TO_NUMBER(pub.YEAR) >=' || TO_NUMBER (p_in_year),
                   'LEQ', 'TO_NUMBER(pub.YEAR) <=' || TO_NUMBER (p_in_year),
                   'NEQ', 'TO_NUMBER(pub.YEAR) !=' || TO_NUMBER (p_in_year))
             || ' AND '
             || CASE
                   WHEN p_in_author_name IS NULL
                   THEN
                      '1=1'
                   WHEN (p_alias_set = 'pub' OR p_dual_set = 1) AND p_in_author_name IS NOT NULL
                   THEN
                         'UPPER(pub.author) like UPPER(''%'
                      || p_in_author_name
                      || '%'')'
                END
                CASE
        INTO p_sql_pubs_stmt
        FROM DUAL;



      SELECT    'select jor.author from ARTICLES_SUBSET jor
              where 1=1 AND '
             || CASE
                   WHEN p_dual_set = 0 AND p_alias_set = 'jor'
                   THEN
                      'jor.JOURNAL in (''' || p_in_journal_name || ''')'
                   WHEN p_dual_set = 1
                   THEN
                      'jor.JOURNAL in (''' || p_in_journal_name || ''')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || CASE
                   WHEN p_alias_set = 'jor' AND p_in_title IS NOT NULL
                   THEN
                         'UPPER(jor.TITLE) LIKE UPPER(''%'
                      || p_in_title
                      || '%'')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || DECODE (
                   p_in_year_option,
                   NULL, '1=1',
                   'EQ', 'TO_NUMBER(jor.YEAR) = ' || TO_NUMBER (p_in_year),
                   'GEQ', 'TO_NUMBER(jor.YEAR) >=' || TO_NUMBER (p_in_year),
                   'LEQ', 'TO_NUMBER(jor.YEAR) <=' || TO_NUMBER (p_in_year),
                   'NEQ', 'TO_NUMBER(jor.YEAR) !=' || TO_NUMBER (p_in_year))
             || ' AND '
             || CASE
                   WHEN p_in_author_name IS NULL
                   THEN
                      '1=1'
                   WHEN (p_alias_set = 'jor' OR p_dual_set = 1) AND p_in_author_name IS NOT NULL
                   THEN
                         'UPPER(jor.author) like UPPER(''%'
                      || p_in_author_name
                      || '%'')'
                END
                CASE
        INTO p_sql_jors_stmt
        FROM DUAL;

      --author_count_pub,author_count_jour
      p_sql_final_stmt := 'SELECT pub_jor_data.author,pub_jor_data.number_of_publications,pub_jor_data.number_of_journals
                            FROM ( 
                            SELECT auth_data.author,number_of_publications,number_of_journals,rownum num FROM ('
                          || CASE
                                WHEN p_dual_set=1 then    
                           p_sql_pubs_stmt
                          || ' UNION '|| 
                          p_sql_jors_stmt 
                          WHEN p_dual_set=0 and p_alias_set='pub' then
                          p_sql_pubs_stmt
                          WHEN p_dual_set=0 and p_alias_set='jor' then
                          p_sql_jors_stmt
                          END
                          ||' )auth_data FULL OUTER JOIN author_count_pub 
                            ON auth_data.author = author_count_pub.author_name
                            FULL OUTER JOIN author_count_jour 
                            ON auth_data.author = author_count_jour.author_name '
                           ||' WHERE ROWNUM <='||p_in_max_pg ||'
                             and number_of_publications >='||p_in_number_of_pubs ||
                            ' and number_of_journals >='||p_in_number_of_jours ||
                            ') pub_jor_data where num >='||p_in_min_pg ; 
            
   ELSE
      SELECT    'select pub.author from PUBLICATIONS_SUBSET pub
              where 1=1 AND '
             || CASE
                   WHEN p_dual_set = 0 AND p_alias_set = 'pub'
                   THEN
                      'pub.booktitle in (''' || p_in_conference_name || ''')'
                   WHEN p_dual_set = 1
                   THEN
                      'pub.booktitle in (''' || p_in_conference_name || ''')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || CASE
                   WHEN p_alias_set = 'pub' AND p_in_title IS NOT NULL
                   THEN
                         'UPPER(pub.TITLE) LIKE UPPER(''%'
                      || p_in_title
                      || '%'')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || DECODE (
                   p_in_year_option,
                   NULL, '1=1',
                   'EQ', 'TO_NUMBER(pub.YEAR) = ' || TO_NUMBER (p_in_year),
                   'GEQ', 'TO_NUMBER(pub.YEAR) >=' || TO_NUMBER (p_in_year),
                   'LEQ', 'TO_NUMBER(pub.YEAR) <=' || TO_NUMBER (p_in_year),
                   'NEQ', 'TO_NUMBER(pub.YEAR) !=' || TO_NUMBER (p_in_year))
             || ' AND '
             || CASE
                   WHEN p_in_author_name IS NULL
                   THEN
                      '1=1'
                   WHEN p_alias_set = 'pub' AND p_in_author_name IS NOT NULL
                   THEN
                         'UPPER(pub.author) like UPPER(''%'
                      || p_in_author_name
                      || '%'')'
                END
                CASE
        INTO p_sql_pubs_stmt
        FROM DUAL;



      SELECT    'select jor.author from ARTICLES_SUBSET jor
              where 1=1 AND '
             || CASE
                   WHEN p_dual_set = 0 AND p_alias_set = 'jor'
                   THEN
                      'jor.JOURNAL in (''' || p_in_journal_name || ''')'
                   WHEN p_dual_set = 1
                   THEN
                      'jor.JOURNAL in (''' || p_in_journal_name || ''')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || CASE
                   WHEN p_alias_set = 'jor' AND p_in_title IS NOT NULL
                   THEN
                         'UPPER(jor.TITLE) LIKE UPPER(''%'
                      || p_in_title
                      || '%'')'
                   ELSE
                      '1=1'
                END
             || ' AND '
             || DECODE (
                   p_in_year_option,
                   NULL, '1=1',
                   'EQ', 'TO_NUMBER(jor.YEAR) = ' || TO_NUMBER (p_in_year),
                   'GEQ', 'TO_NUMBER(jor.YEAR) >=' || TO_NUMBER (p_in_year),
                   'LEQ', 'TO_NUMBER(jor.YEAR) <=' || TO_NUMBER (p_in_year),
                   'NEQ', 'TO_NUMBER(jor.YEAR) !=' || TO_NUMBER (p_in_year))
             || ' AND '
             || CASE
                   WHEN p_in_author_name IS NULL
                   THEN
                      '1=1'
                   WHEN p_alias_set = 'jor' AND p_in_author_name IS NOT NULL
                   THEN
                         'UPPER(jor.author) like UPPER(''%'
                      || p_in_author_name
                      || '%'')'
                END
                CASE
        INTO p_sql_jors_stmt
        FROM DUAL;

      p_sql_final_stmt := 'SELECT pub_jor_data.author,pub_jor_data.number_of_publications,pub_jor_data.number_of_journals
                            FROM ( 
                            SELECT auth_data.author,number_of_publications,number_of_journals,rownum num FROM ('
                          || CASE
                                WHEN p_dual_set=1 then    
                           p_sql_pubs_stmt
                          || ' INTERSECT '|| 
                          p_sql_jors_stmt 
                          WHEN p_dual_set=0 and p_alias_set='pub' then
                          p_sql_pubs_stmt
                          WHEN p_dual_set=0 and p_alias_set='jor' then
                          p_sql_jors_stmt
                          
                          END
                          ||' )auth_data FULL OUTER JOIN author_count_pub 
                            ON auth_data.author = author_count_pub.author_name
                            FULL OUTER JOIN author_count_jour 
                            ON auth_data.author = author_count_jour.author_name '
                           ||' WHERE ROWNUM <='||p_in_max_pg ||'
                             and number_of_publications >='||p_in_number_of_pubs ||
                            ' and number_of_journals >='||p_in_number_of_jours ||
                            ') pub_jor_data where num >='||p_in_min_pg ; 
   END IF;



   DBMS_OUTPUT.PUT_LINE (p_sql_final_stmt);

   CASE
      WHEN p_dual_set = 1
      THEN
         DBMS_OUTPUT.PUT_LINE (
            p_sql_pubs_stmt || ' UNION ' || p_sql_jors_stmt);
      WHEN p_dual_set = 0 AND p_alias_set = 'pub'
      THEN
         DBMS_OUTPUT.PUT_LINE (p_sql_pubs_stmt);
      WHEN p_dual_set = 0 AND p_alias_set = 'jor'
      THEN
         DBMS_OUTPUT.PUT_LINE (p_sql_jors_stmt);
      ELSE
         DBMS_OUTPUT.PUT_LINE ('No VALID INPUR');
   END CASE;
   
   EXCEPTION 
    WHEN no_options_enabled 
    THEN p_out_error_message:='No Options were enabled';
    
   
END;