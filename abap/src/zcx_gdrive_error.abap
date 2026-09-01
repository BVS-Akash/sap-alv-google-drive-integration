CLASS zcx_gdrive_error DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    DATA mv_message            TYPE string READ-ONLY.
    DATA mv_http_status        TYPE i READ-ONLY.
    DATA mv_google_error_code  TYPE i READ-ONLY.
    DATA mv_google_message     TYPE string READ-ONLY.
    DATA mv_google_reason      TYPE string READ-ONLY.

    METHODS constructor
      IMPORTING
        iv_message           TYPE string OPTIONAL
        iv_http_status       TYPE i OPTIONAL
        iv_google_error_code TYPE i OPTIONAL
        iv_google_message    TYPE string OPTIONAL
        iv_google_reason     TYPE string OPTIONAL
        previous             TYPE REF TO cx_root OPTIONAL.
ENDCLASS.

CLASS zcx_gdrive_error IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_message           = iv_message.
    mv_http_status       = iv_http_status.
    mv_google_error_code = iv_google_error_code.
    mv_google_message    = iv_google_message.
    mv_google_reason     = iv_google_reason.
  ENDMETHOD.
ENDCLASS.
