// Sobrescribir mensajes de jQuery Validation a español
if (typeof jQuery !== 'undefined' && jQuery.validator) {
    jQuery.extend(jQuery.validator.messages, {
        required: "Este campo es obligatorio.",
        remote: "Por favor, corrija este campo.",
        email: "Por favor, ingrese un correo electrónico válido.",
        url: "Por favor, ingrese una URL válida.",
        date: "Por favor, ingrese una fecha válida.",
        dateISO: "Por favor, ingrese una fecha válida (ISO).",
        number: "Por favor, ingrese un número válido.",
        digits: "Por favor, ingrese solo dígitos.",
        creditcard: "Por favor, ingrese un número de tarjeta válido.",
        equalTo: "Por favor, ingrese el mismo valor nuevamente.",
        maxlength: jQuery.validator.format("Por favor, no ingrese más de {0} caracteres."),
        minlength: jQuery.validator.format("Por favor, ingrese al menos {0} caracteres."),
        rangelength: jQuery.validator.format("Por favor, ingrese entre {0} y {1} caracteres."),
        range: jQuery.validator.format("Por favor, ingrese un valor entre {0} y {1}."),
        max: jQuery.validator.format("Por favor, ingrese un valor menor o igual a {0}."),
        min: jQuery.validator.format("Por favor, ingrese un valor mayor o igual a {0}.")
    });
}
