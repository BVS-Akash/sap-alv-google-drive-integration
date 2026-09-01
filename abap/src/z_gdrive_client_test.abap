REPORT z_gdrive_client_test.

PARAMETERS p_oauth TYPE string LOWER CASE OBLIGATORY.

START-OF-SELECTION.
  TRY.
      DATA(lo_gdrive) = NEW zcl_gdrive_client( iv_oauth_profile = p_oauth ).

      IF lo_gdrive->test_connection( ) = abap_true.
        WRITE: / 'Authenticated Google Drive connection succeeded.'.
      ENDIF.
    CATCH zcx_gdrive_error INTO DATA(lx_gdrive).
      DATA(lv_message) = COND string(
        WHEN lx_gdrive->mv_google_message IS NOT INITIAL THEN lx_gdrive->mv_google_message
        ELSE lx_gdrive->mv_message ).
      WRITE: / |Google Drive request failed (HTTP { lx_gdrive->mv_http_status }): { lv_message }|.
  ENDTRY.
