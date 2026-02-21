json.error @error if defined?(@error) && @error.present?
json.errors @errors if defined?(@errors) && @errors.present?
json.message @message if defined?(@message) && @message.present?
