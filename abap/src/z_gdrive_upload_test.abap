REPORT z_gdrive_upload_test.

"Foreground utility for verifying a configured OA2C profile with a real file.
"The selected file is read as raw bytes so CSV and Excel content is not altered.

PARAMETERS:
  p_oauth TYPE string OBLIGATORY,
  p_file  TYPE rlgrap-filename OBLIGATORY.

CLASS lcl_file_upload DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    CLASS-METHODS choose_file CHANGING cv_file TYPE rlgrap-filename.
    CLASS-METHODS read_file_as_xstring
      IMPORTING iv_file TYPE rlgrap-filename
      RETURNING VALUE(rv_content) TYPE xstring
      RAISING   zcx_gdrive_error.
    CLASS-METHODS get_file_name
      IMPORTING iv_file TYPE rlgrap-filename
      RETURNING VALUE(rv_file_name) TYPE string
      RAISING   zcx_gdrive_error.
    CLASS-METHODS get_mime_type
      IMPORTING iv_file_name TYPE string
      RETURNING VALUE(rv_mime_type) TYPE string
      RAISING   zcx_gdrive_error.
ENDCLASS.

CLASS lcl_file_upload IMPLEMENTATION.
  METHOD choose_file.
    DATA lt_files TYPE filetable.
    DATA lv_count TYPE i.
    DATA lv_action TYPE i.
    cl_gui_frontend_services=>file_open_dialog(
      CHANGING file_table = lt_files rc = lv_count user_action = lv_action
      EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0 AND lv_action = cl_gui_frontend_services=>action_ok AND lv_count > 0.
      cv_file = lt_files[ 1 ]-filename.
    ENDIF.
  ENDMETHOD.

  METHOD read_file_as_xstring.
    "GUI_UPLOAD with FILETYPE BIN avoids a code-page conversion for XLSX and CSV.
    DATA lt_binary TYPE STANDARD TABLE OF x255 WITH EMPTY KEY.
    DATA lv_file_length TYPE i.
    cl_gui_frontend_services=>gui_upload(
      EXPORTING filename = CONV string( iv_file ) filetype = 'BIN'
      IMPORTING filelength = lv_file_length
      CHANGING  data_tab = lt_binary
      EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_gdrive_error(
        iv_message = |Could not read the selected frontend file: { iv_file }| ).
    ENDIF.
    CALL FUNCTION 'SCMS_BINARY_TO_XSTRING'
      EXPORTING input_length = lv_file_length
      IMPORTING buffer = rv_content
      TABLES    binary_tab = lt_binary
      EXCEPTIONS failed = 1 OTHERS = 2.
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_gdrive_error(
        iv_message = 'Could not convert the selected file to XSTRING.' ).
    ENDIF.
  ENDMETHOD.

  METHOD get_file_name.
    "Drive receives only the leaf name, never a local workstation path.
    rv_file_name = iv_file.
    REPLACE ALL OCCURRENCES OF REGEX '^.*[\\/]' IN rv_file_name WITH ''.
    IF rv_file_name IS INITIAL.
      RAISE EXCEPTION NEW zcx_gdrive_error( iv_message = 'The selected file name is empty.' ).
    ENDIF.
  ENDMETHOD.

  METHOD get_mime_type.
    DATA(lv_lower_name) = to_lower( iv_file_name ).
    IF lv_lower_name CP '*.csv'.
      rv_mime_type = 'text/csv'.
    ELSEIF lv_lower_name CP '*.xlsx'.
      rv_mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'.
    ELSEIF lv_lower_name CP '*.xls'.
      rv_mime_type = 'application/vnd.ms-excel'.
    ELSE.
      RAISE EXCEPTION NEW zcx_gdrive_error( iv_message = 'Select a CSV, XLSX, or XLS file.' ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

AT SELECTION-SCREEN ON VALUE-REQUEST FOR p_file.
  lcl_file_upload=>choose_file( CHANGING cv_file = p_file ).

START-OF-SELECTION.
  TRY.
      DATA(lv_file_name) = lcl_file_upload=>get_file_name( p_file ).
      DATA(lv_mime_type) = lcl_file_upload=>get_mime_type( lv_file_name ).
      DATA(lv_content) = lcl_file_upload=>read_file_as_xstring( p_file ).
      DATA(lo_gdrive) = NEW zcl_gdrive_client( iv_oauth_profile = p_oauth ).

      "The client chooses multipart or resumable upload according to file size.
      DATA(ls_upload) = lo_gdrive->upload_file(
        iv_file_name    = lv_file_name
        iv_mime_type    = lv_mime_type
        iv_file_content = lv_content ).

      WRITE: / |Uploaded { ls_upload-file_name } successfully.|,
             / |Google Drive file ID: { ls_upload-file_id }|,
             / |MIME type: { ls_upload-mime_type }|.
      IF ls_upload-web_view_link IS NOT INITIAL.
        WRITE: / |Open file: { ls_upload-web_view_link }|.
      ENDIF.
    CATCH zcx_gdrive_error INTO DATA(lx_gdrive).
      DATA(lv_message) = COND string(
        WHEN lx_gdrive->mv_google_message IS NOT INITIAL THEN lx_gdrive->mv_google_message
        ELSE lx_gdrive->mv_message ).
      WRITE: / |Google Drive upload failed (HTTP { lx_gdrive->mv_http_status }): { lv_message }|.
  ENDTRY.
