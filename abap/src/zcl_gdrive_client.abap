CLASS zcl_gdrive_client DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES: BEGIN OF ty_upload_result,
             file_id       TYPE string,
             file_name     TYPE string,
             mime_type     TYPE string,
             web_view_link TYPE string,
             created_time  TYPE string,
           END OF ty_upload_result.

    METHODS constructor
      IMPORTING iv_oauth_profile TYPE string.

    METHODS get_oauth_token
      RETURNING VALUE(rv_access_token) TYPE string
      RAISING   zcx_gdrive_error.

    METHODS test_connection
      RETURNING VALUE(rv_success) TYPE abap_bool
      RAISING   zcx_gdrive_error.

    METHODS upload_file
      IMPORTING
        iv_file_name    TYPE string
        iv_mime_type    TYPE string
        iv_file_content TYPE xstring
      RETURNING VALUE(rs_result) TYPE ty_upload_result
      RAISING   zcx_gdrive_error.

    "Use this convenience method when the caller already holds CSV data as XSTRING.
    METHODS upload_csv
      IMPORTING
        iv_file_name   TYPE string
        iv_csv_content TYPE xstring
      RETURNING VALUE(rs_result) TYPE ty_upload_result
      RAISING   zcx_gdrive_error.

    "Use the generic method when a non-default Excel MIME type is required.
    METHODS upload_excel
      IMPORTING
        iv_file_name     TYPE string
        iv_excel_content TYPE xstring
        iv_mime_type     TYPE string DEFAULT 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      RETURNING VALUE(rs_result) TYPE ty_upload_result
      RAISING   zcx_gdrive_error.

  PRIVATE SECTION.
    CONSTANTS:
      gc_about_url  TYPE string VALUE 'https://www.googleapis.com/drive/v3/about?fields=user,storageQuota',
      gc_upload_url TYPE string VALUE 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart',
      gc_resumable_upload_url TYPE string VALUE 'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable',
      gc_auth_name  TYPE string VALUE 'Authorization',
      gc_accept     TYPE string VALUE 'Accept'.
    CONSTANTS:
      gc_small_file_limit TYPE i VALUE 5242880,
      gc_upload_chunk_size TYPE i VALUE 5242880.

    TYPES: BEGIN OF ty_file_metadata,
             name TYPE string,
           END OF ty_file_metadata,
           BEGIN OF ty_file_response,
             id            TYPE string,
             name          TYPE string,
             mime_type     TYPE string,
             web_view_link TYPE string,
             created_time  TYPE string,
           END OF ty_file_response,
           BEGIN OF ty_google_error_detail,
             reason TYPE string,
           END OF ty_google_error_detail,
           ty_google_error_details TYPE STANDARD TABLE OF ty_google_error_detail WITH EMPTY KEY,
           BEGIN OF ty_google_error_body,
             code    TYPE i,
             message TYPE string,
             errors  TYPE ty_google_error_details,
           END OF ty_google_error_body,
           BEGIN OF ty_error_response,
             error TYPE ty_google_error_body,
           END OF ty_error_response.

    DATA mv_oauth_profile TYPE string.
    DATA mo_oauth_client  TYPE REF TO if_oauth2_client.

    METHODS create_http_client
      IMPORTING iv_url TYPE string
      RETURNING VALUE(ro_client) TYPE REF TO if_http_client
      RAISING   zcx_gdrive_error.
    METHODS execute_request
      IMPORTING io_client TYPE REF TO if_http_client
      RAISING   zcx_gdrive_error.
    METHODS set_authorization_header
      IMPORTING io_client TYPE REF TO if_http_client
      RAISING   zcx_gdrive_error.
    METHODS set_common_headers
      IMPORTING io_client TYPE REF TO if_http_client
      RAISING   zcx_gdrive_error.
    METHODS set_multipart_headers
      IMPORTING
        io_client TYPE REF TO if_http_client
        iv_boundary TYPE string.
    METHODS set_resumable_session_headers
      IMPORTING
        io_client TYPE REF TO if_http_client
        iv_mime_type TYPE string
        iv_file_size TYPE i.
    METHODS set_resumable_chunk_headers
      IMPORTING
        io_client TYPE REF TO if_http_client
        iv_mime_type TYPE string
        iv_chunk_length TYPE i
        iv_first_byte TYPE i
        iv_last_byte TYPE i
        iv_total_size TYPE i.
    METHODS set_text_body
      IMPORTING
        io_client TYPE REF TO if_http_client
        iv_body TYPE string.
    METHODS set_binary_body
      IMPORTING
        io_client TYPE REF TO if_http_client
        iv_body TYPE xstring.
    METHODS get_oauth_client
      RETURNING VALUE(ro_oauth_client) TYPE REF TO if_oauth2_client
      RAISING   zcx_gdrive_error.
    METHODS apply_oauth_token
      IMPORTING io_client TYPE REF TO if_http_client
      RAISING   zcx_gdrive_error.
    METHODS build_file_metadata_json
      IMPORTING iv_file_name TYPE string
      RETURNING VALUE(rv_json) TYPE string.
    METHODS parse_file_response
      IMPORTING iv_json TYPE string
      RETURNING VALUE(rs_response) TYPE ty_file_response.
    METHODS parse_error_response
      IMPORTING iv_json TYPE string
      RETURNING VALUE(rs_error) TYPE ty_error_response.
    METHODS raise_http_error
      IMPORTING
        io_client      TYPE REF TO if_http_client
        iv_http_status TYPE i
      RAISING zcx_gdrive_error.
    METHODS validate_upload_input
      IMPORTING
        iv_file_name TYPE string
        iv_mime_type TYPE string
      RAISING zcx_gdrive_error.
    METHODS upload_large_file
      IMPORTING
        iv_file_name    TYPE string
        iv_mime_type    TYPE string
        iv_file_content TYPE xstring
      RETURNING VALUE(rs_result) TYPE ty_upload_result
      RAISING   zcx_gdrive_error.
    METHODS create_resumable_session
      IMPORTING
        iv_file_name TYPE string
        iv_mime_type TYPE string
        iv_file_size TYPE i
      RETURNING VALUE(rv_session_url) TYPE string
      RAISING   zcx_gdrive_error.
ENDCLASS.

CLASS zcl_gdrive_client IMPLEMENTATION.
  METHOD constructor.
    mv_oauth_profile = iv_oauth_profile.
  ENDMETHOD.

  METHOD get_oauth_token.
    "The OA2C framework applies its managed token directly to an HTTP request.
    "This probe is not sent and exists solely to preserve this public API.
    DATA(lo_probe_client) = create_http_client( gc_about_url ).
    apply_oauth_token( lo_probe_client ).
    DATA(lv_authorization) = lo_probe_client->request->get_header_field( name = gc_auth_name ).
    lo_probe_client->close( ).
    IF lv_authorization NP 'Bearer *'.
      RAISE EXCEPTION NEW zcx_gdrive_error(
        iv_message = 'SAP OAuth did not provide a Bearer authorization header.' ).
    ENDIF.
    rv_access_token = lv_authorization+7.
  ENDMETHOD.

  METHOD test_connection.
    DATA(lo_client) = create_http_client( gc_about_url ).
    set_common_headers( lo_client ).
    lo_client->request->set_method( if_http_request=>co_request_method_get ).
    execute_request( lo_client ).

    DATA(lv_status) = lo_client->response->get_status( ).
    IF lv_status <> 200.
      raise_http_error( io_client = lo_client iv_http_status = lv_status ).
    ENDIF.
    rv_success = abap_true.
    lo_client->close( ).
  ENDMETHOD.

  METHOD upload_file.
    validate_upload_input( iv_file_name = iv_file_name iv_mime_type = iv_mime_type ).

    "Drive multipart upload sends metadata and content together; large files use chunks.
    IF xstrlen( iv_file_content ) > gc_small_file_limit.
      rs_result = upload_large_file(
        iv_file_name    = iv_file_name
        iv_mime_type    = iv_mime_type
        iv_file_content = iv_file_content ).
      RETURN.
    ENDIF.

    "For small files, Drive accepts metadata and binary content in one request.
    DATA(lv_boundary) = |----SAPGDrive{ cl_system_uuid=>create_uuid_c32_static( ) }|.
    DATA(lv_metadata) = build_file_metadata_json( iv_file_name ).
    DATA(lv_prefix) = |--{ lv_boundary }\r\n| &&
                      |Content-Type: application/json; charset=UTF-8\r\n\r\n| &&
                      |{ lv_metadata }\r\n--{ lv_boundary }\r\n| &&
                      |Content-Type: { iv_mime_type }\r\n\r\n|.
    DATA(lv_suffix) = |\r\n--{ lv_boundary }--\r\n|.
    DATA(lv_body) = cl_bcs_convert=>string_to_xstring( iv_string = lv_prefix ).
    lv_body = lv_body && iv_file_content && cl_bcs_convert=>string_to_xstring( iv_string = lv_suffix ).

    DATA(lo_client) = create_http_client( gc_upload_url ).
    set_common_headers( lo_client ).
    lo_client->request->set_method( if_http_request=>co_request_method_post ).
    set_multipart_headers( io_client = lo_client iv_boundary = lv_boundary ).
    set_binary_body( io_client = lo_client iv_body = lv_body ).
    execute_request( lo_client ).

    DATA(lv_status) = lo_client->response->get_status( ).
    IF lv_status <> 200 AND lv_status <> 201.
      raise_http_error( io_client = lo_client iv_http_status = lv_status ).
    ENDIF.

    DATA(ls_file) = parse_file_response( lo_client->response->get_cdata( ) ).
    rs_result = VALUE #( file_id       = ls_file-id
                         file_name     = ls_file-name
                         mime_type     = ls_file-mime_type
                         web_view_link = ls_file-web_view_link
                         created_time  = ls_file-created_time ).
    lo_client->close( ).
  ENDMETHOD.

  METHOD upload_csv.
    rs_result = upload_file(
      iv_file_name    = iv_file_name
      iv_mime_type    = 'text/csv'
      iv_file_content = iv_csv_content ).
  ENDMETHOD.

  METHOD upload_excel.
    rs_result = upload_file(
      iv_file_name    = iv_file_name
      iv_mime_type    = iv_mime_type
      iv_file_content = iv_excel_content ).
  ENDMETHOD.

  METHOD create_http_client.
    cl_http_client=>create_by_url(
      EXPORTING url = iv_url
      IMPORTING client = ro_client
      EXCEPTIONS argument_not_found = 1 plugin_not_active = 2 internal_error = 3 OTHERS = 4 ).
    IF sy-subrc <> 0 OR ro_client IS INITIAL.
      RAISE EXCEPTION NEW zcx_gdrive_error( iv_message = 'Could not create the HTTPS client.' ).
    ENDIF.
  ENDMETHOD.

  METHOD execute_request.
    "Keep transport handling in one place so all Drive calls return consistent errors.
    CALL METHOD io_client->send
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4.
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_gdrive_error(
        iv_message = 'HTTPS request could not be sent. Check TLS, proxy, DNS, and network connectivity.' ).
    ENDIF.

    CALL METHOD io_client->receive
      EXCEPTIONS
        http_communication_failure = 1
        http_invalid_state         = 2
        http_processing_failed     = 3
        OTHERS                     = 4.
    IF sy-subrc <> 0.
      RAISE EXCEPTION NEW zcx_gdrive_error(
        iv_message = 'HTTPS response could not be received. Check TLS, proxy, DNS, and network connectivity.' ).
    ENDIF.
  ENDMETHOD.

  METHOD set_authorization_header.
    apply_oauth_token( io_client ).
  ENDMETHOD.

  METHOD set_common_headers.
    "Every Google Drive call is authenticated and requests a JSON response.
    set_authorization_header( io_client ).
    io_client->request->set_header_field( name = gc_accept value = 'application/json' ).
  ENDMETHOD.

  METHOD set_multipart_headers.
    io_client->request->set_header_field(
      name  = 'Content-Type'
      value = |multipart/related; boundary={ iv_boundary }| ).
  ENDMETHOD.

  METHOD set_resumable_session_headers.
    io_client->request->set_header_field( name = 'Content-Type' value = 'application/json; charset=UTF-8' ).
    io_client->request->set_header_field( name = 'X-Upload-Content-Type' value = iv_mime_type ).
    io_client->request->set_header_field( name = 'X-Upload-Content-Length' value = |{ iv_file_size }| ).
  ENDMETHOD.

  METHOD set_resumable_chunk_headers.
    io_client->request->set_header_field( name = 'Content-Type' value = iv_mime_type ).
    io_client->request->set_header_field( name = 'Content-Length' value = |{ iv_chunk_length }| ).
    io_client->request->set_header_field(
      name  = 'Content-Range'
      value = |bytes { iv_first_byte }-{ iv_last_byte }/{ iv_total_size }| ).
  ENDMETHOD.

  METHOD set_text_body.
    io_client->request->set_cdata( iv_body ).
  ENDMETHOD.

  METHOD set_binary_body.
    "SET_DATA preserves the caller's XSTRING bytes without character conversion.
    io_client->request->set_data( iv_body ).
  ENDMETHOD.

  METHOD get_oauth_client.
    IF mo_oauth_client IS INITIAL.
      TRY.
          mo_oauth_client = cl_oauth2_client=>create(
            i_profile = CONV oa2c_profile( mv_oauth_profile ) ).
        CATCH cx_oa2c INTO DATA(lx_oauth).
          RAISE EXCEPTION NEW zcx_gdrive_error(
            iv_message = |Could not create SAP OAuth client: { lx_oauth->get_text( ) }| ).
      ENDTRY.
    ENDIF.
    ro_oauth_client = mo_oauth_client.
  ENDMETHOD.

  METHOD apply_oauth_token.
    DATA(lo_oauth_client) = get_oauth_client( ).
    TRY.
        lo_oauth_client->set_token(
          io_http_client = io_client
          i_param_kind   = if_oauth2_client=>c_param_kind_header_field ).
      CATCH cx_oa2c_at_expired.
        TRY.
            lo_oauth_client->execute_refresh_flow( ).
            lo_oauth_client->set_token(
              io_http_client = io_client
              i_param_kind   = if_oauth2_client=>c_param_kind_header_field ).
          CATCH cx_oa2c INTO DATA(lx_refresh).
            RAISE EXCEPTION NEW zcx_gdrive_error(
              iv_message = |SAP OAuth refresh failed: { lx_refresh->get_text( ) }| ).
        ENDTRY.
      CATCH cx_oa2c INTO DATA(lx_oauth).
        RAISE EXCEPTION NEW zcx_gdrive_error(
          iv_message = |SAP OAuth token setup failed: { lx_oauth->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  METHOD build_file_metadata_json.
    rv_json = /ui2/cl_json=>serialize(
      data = VALUE ty_file_metadata( name = iv_file_name )
      compress = abap_true
      pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).
  ENDMETHOD.

  METHOD parse_file_response.
    /ui2/cl_json=>deserialize(
      EXPORTING json = iv_json pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data = rs_response ).
  ENDMETHOD.

  METHOD parse_error_response.
    /ui2/cl_json=>deserialize(
      EXPORTING json = iv_json pretty_name = /ui2/cl_json=>pretty_mode-camel_case
      CHANGING  data = rs_error ).
  ENDMETHOD.

  METHOD raise_http_error.
    DATA(ls_error) = parse_error_response( io_client->response->get_cdata( ) ).
    DATA(lv_reason) = VALUE string( ).
    IF lines( ls_error-error-errors ) > 0.
      lv_reason = ls_error-error-errors[ 1 ]-reason.
    ENDIF.
    RAISE EXCEPTION NEW zcx_gdrive_error(
      iv_message           = COND #( WHEN ls_error-error-message IS NOT INITIAL THEN ls_error-error-message ELSE |Google Drive HTTP error { iv_http_status }| )
      iv_http_status       = iv_http_status
      iv_google_error_code = ls_error-error-code
      iv_google_message    = ls_error-error-message
      iv_google_reason     = lv_reason ).
  ENDMETHOD.

  METHOD validate_upload_input.
    IF iv_file_name IS INITIAL OR iv_mime_type IS INITIAL.
      RAISE EXCEPTION NEW zcx_gdrive_error( iv_message = 'File name and MIME type are required.' ).
    ENDIF.
  ENDMETHOD.

  METHOD upload_large_file.
    DATA(lv_total_size) = xstrlen( iv_file_content ).
    DATA(lv_session_url) = create_resumable_session(
      iv_file_name = iv_file_name
      iv_mime_type = iv_mime_type
      iv_file_size = lv_total_size ).
    DATA(lv_offset) = 0.

    WHILE lv_offset < lv_total_size.
      DATA(lv_chunk_length) = COND i(
        WHEN lv_total_size - lv_offset > gc_upload_chunk_size
        THEN gc_upload_chunk_size
        ELSE lv_total_size - lv_offset ).
      DATA(lv_last_byte) = lv_offset + lv_chunk_length - 1.
      DATA(lv_chunk) = iv_file_content+lv_offset(lv_chunk_length).
      DATA(lo_client) = create_http_client( lv_session_url ).
      set_common_headers( lo_client ).
      lo_client->request->set_method( if_http_request=>co_request_method_put ).
      set_resumable_chunk_headers(
        io_client      = lo_client
        iv_mime_type   = iv_mime_type
        iv_chunk_length = lv_chunk_length
        iv_first_byte  = lv_offset
        iv_last_byte   = lv_last_byte
        iv_total_size  = lv_total_size ).
      set_binary_body( io_client = lo_client iv_body = lv_chunk ).
      execute_request( lo_client ).

      DATA(lv_status) = lo_client->response->get_status( ).
      IF lv_status = 200 OR lv_status = 201.
        DATA(ls_file) = parse_file_response( lo_client->response->get_cdata( ) ).
        rs_result = VALUE #( file_id       = ls_file-id
                             file_name     = ls_file-name
                             mime_type     = ls_file-mime_type
                             web_view_link = ls_file-web_view_link
                             created_time  = ls_file-created_time ).
        lo_client->close( ).
        RETURN.
      ENDIF.
      IF lv_status <> 308.
        raise_http_error( io_client = lo_client iv_http_status = lv_status ).
      ENDIF.
      lo_client->close( ).
      lv_offset = lv_offset + lv_chunk_length.
    ENDWHILE.

    RAISE EXCEPTION NEW zcx_gdrive_error(
      iv_message = 'Resumable upload ended without a final Google Drive response.' ).
  ENDMETHOD.

  METHOD create_resumable_session.
    "This POST creates a temporary Drive upload URL; file bytes are sent only afterwards.
    DATA(lo_client) = create_http_client( gc_resumable_upload_url ).
    set_common_headers( lo_client ).
    lo_client->request->set_method( if_http_request=>co_request_method_post ).
    set_resumable_session_headers(
      io_client = lo_client iv_mime_type = iv_mime_type iv_file_size = iv_file_size ).
    set_text_body( io_client = lo_client iv_body = build_file_metadata_json( iv_file_name ) ).
    execute_request( lo_client ).

    DATA(lv_status) = lo_client->response->get_status( ).
    IF lv_status <> 200 AND lv_status <> 201.
      raise_http_error( io_client = lo_client iv_http_status = lv_status ).
    ENDIF.
    rv_session_url = lo_client->response->get_header_field( name = 'Location' ).
    lo_client->close( ).
    IF rv_session_url IS INITIAL.
      RAISE EXCEPTION NEW zcx_gdrive_error(
        iv_message = 'Google Drive did not return a resumable-upload session URL.' ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.
