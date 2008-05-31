open Utils
open Verify

exception Problem_sending_email

type submission_info = {
  to_addrs : string list;
  comment : string option;
}

type user_info = {
  user_name : string;
  user_email_addr : string;
}


let get_list_of_comma_delimited_strings comma_strings = 
  List.map Utils.trim (Str.split (Str.regexp ",") comma_strings)
      
let send_email from_name from_addr to_addrs cc_addrs subject content = 
  let rec comma_delimited_list_of_strings strs = 
    match List.length strs with
        0 -> ""
      | 1 -> List.hd strs
      | _ -> List.hd strs ^ "," ^ comma_delimited_list_of_strings (List.tl strs)
  in
  let get_raw_email_text_for_sendmail () =
    "From: \"" ^ from_name ^ "\" <" ^ from_addr ^ ">\n" ^ 
      (if List.length to_addrs>0 then "To: " ^ comma_delimited_list_of_strings to_addrs ^ "\n" else "") ^
      (if List.length cc_addrs>0 then "Cc: " ^ comma_delimited_list_of_strings cc_addrs ^ "\n" else "") ^
      "Subject: " ^ subject ^ "\n" ^
      content
  in
    match Sys.command ("echo \""^get_raw_email_text_for_sendmail ()^"\" | sendmail " ^ comma_delimited_list_of_strings (to_addrs@cc_addrs)) with
        0 -> ignore()
      | _ -> raise Problem_sending_email
          
let send_test_email () = 
  send_email "piVC" "nobody@nobody.com" (get_list_of_comma_delimited_strings (Config.get_cmd_line_value "test_email_addr")) [] "piVC Test Email" "This is a test email. The fact that you are receiving this email suggests that piVC's email functionality is working correctly.";
  print_endline "Test email sent. Check your inbox (or spam filter)."
    
let send_error_notification message =
  let to_addrs_config_str = Config.get_value "error_notification_addrs" in
    match to_addrs_config_str with
        "" -> ignore ()
      | _ ->
          begin
            let to_addrs = get_list_of_comma_delimited_strings to_addrs_config_str in
              send_email "piVC" "nobody@nobody.com" to_addrs [] "piVC Exception" message
          end
            
let email_heading str = 
  str ^ "\n" ^ (Str.global_replace (Str.regexp ".") "-" str) ^ "\n"
    
let email_segment_of_options options =
  email_heading "Options" ^ 
    "Generate runtime assertions: " ^ string_of_bool options.generate_runtime_assertions ^ "\n" ^
    "Find inductive core: " ^ string_of_bool options.find_inductive_core ^ "\n"

let email_segment_of_user user = 
  email_heading "User" ^
    "Name: " ^ user.user_name ^ "\n" ^
    "Email address: " ^ user.user_email_addr ^ "\n"
    
let go_submit code submission_info user_info options verified_program_info errors = 
  let (overall_status, problem_message) = 
    match errors with
        []->
          begin
            match (Verify.overall_validity_of_function_validity_information_list (elem_from_opt verified_program_info)) with
                Valid -> ("valid", None)
              | Invalid -> ("invalid", Some("verify correctly"))
              | Unknown -> ("unknown", Some("verify correctly"))
          end
      | _ -> ("does not compile", Some("compile"))
  in

  let warning_message = 
    match problem_message with
        Some(msg) -> "Important note: the code you submitted does not " ^ msg ^ ".\nIf this is not what you intended, you should fix the problem and re-submit." 
      | None -> ""
  in
  let message = "Your program was submitted. A confirmation email has been sent to you.\n\n(If you do not recieve an email, check your spam filter.)" ^
    match warning_message with
        "" -> ""
      | _ -> "\n\n" ^ warning_message
  in
    (*First we deal with the email to the submission address*)
  let email_text = email_segment_of_user user_info ^ "\n" ^
    email_heading "Status" ^ overall_status ^ "\n\n" ^
    begin
      match submission_info.comment with
          Some(comment) -> email_heading "Comments" ^ comment ^ "\n\n"
        | None -> ""
    end ^
    email_segment_of_options options ^ "\n" ^
    email_heading "Code" ^ code
  in
  let email_subject = "[piVC-submission] " ^ user_info.user_name ^ ": " ^ overall_status ^
    match submission_info.comment with
        Some(_) -> " (student wrote comment)"
      | None -> ""
  in
    (*Now we deal with the confirmation email to the student*)
  let confirmation_email_text = "Hi " ^ List.hd ((Str.split (Str.regexp " ") user_info.user_name)) ^ ", \n\n" ^
    "This email serves as confirmation that the following program has been succesfully submitted.\n\n" ^ 
    begin
      match warning_message with
          "" -> ""
        | _ -> warning_message ^ "\n\n"
    end ^
    begin
      match submission_info.comment with
          Some(comment) -> email_heading "Your Comments" ^ comment ^ "\n\n"
        | None -> ""
    end ^
    email_heading "Code" ^ code
  in
    send_email "piVC" "noreply@noreply.com" submission_info.to_addrs  [] email_subject email_text;
    send_email "piVC" "noreply@noreply.com" [user_info.user_email_addr] [] "Confirmation of piVC Submission" confirmation_email_text;
    message



