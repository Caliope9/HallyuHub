# Estándares de respuesta de seguridad infantil de HallyuHub

Última actualización: 20 de septiembre de 2026.

Este documento define el procedimiento operativo de HallyuHub para reportes
relacionados con explotación o abuso sexual infantil. No afirma que exista una
integración automática con autoridades ni que haya un proveedor automático de
detección de CSAM.

## Alcance

HallyuHub prohíbe el CSAM, la explotación sexual de menores, el grooming, la
sextorsión, el tráfico sexual infantil y cualquier intento de solicitar,
producir, distribuir o facilitar ese material.

La edad mínima de HallyuHub es 16 años. Las cuentas de 16 y 17 años tienen
protecciones reforzadas. Estas protecciones no sustituyen la revisión de un
reporte crítico.

## Reporte crítico

La aplicación ofrece el motivo “Explotación o abuso sexual infantil”. Ese
reporte se guarda como `content_reports.reason = 'child_safety'` y agrega
metadata `safety_category = 'child_safety'`, `severity = 'critical'`,
`priority = 'urgent'` y `requires_immediate_review = true`.

La persona que reporta no debe adjuntar ni reenviar material ilegal. Debe
aportar únicamente los datos necesarios para localizar el contenido y describir
el riesgo.

## Revisión y acciones

1. Un moderador o administrador autorizado revisa inmediatamente el reporte.
2. Se registra el estado del reporte, la identidad del revisor, la fecha y una
   nota interna.
3. Se conserva la metadata técnica mínima: `report_id`, `reporter_id`,
   `reported_user_id`, `content_type`, `content_id`, timestamps y referencias a
   las acciones de moderación.
4. Si existe riesgo actual, se oculta el contenido mediante el flujo de
   moderación disponible y se restringe, suspende o banea la cuenta según la
   evidencia y la ley aplicable.
5. La acción queda registrada en `moderation_actions`. Ocultar contenido no
   implica destruir inmediatamente las referencias de auditoría.

No se guardan copias adicionales del material ilegal ni se descarga o replica
contenido reportado para la investigación.

## Cuándo se considera confirmado

Un reporte no se considera confirmado solo por la elección del motivo. Se
considera confirmado cuando un moderador autorizado, después de revisar la
evidencia disponible y el contexto, concluye razonablemente que el contenido o
la conducta constituye CSAM o explotación sexual infantil y deja constancia de
esa decisión en la nota y acción de moderación.

Los casos dudosos se mantienen en revisión y se escalan internamente para una
segunda evaluación. No se promete una clasificación automática.

## Escalamiento legal

Cuando el caso confirmado deba reportarse por ley, el responsable de seguridad
infantil reúne únicamente la información legalmente necesaria y lo deriva a la
autoridad competente del país aplicable.

Para casos sujetos a jurisdicción de Estados Unidos, el punto de referencia es
NCMEC cuando corresponda legalmente. Para otros países, se utiliza la autoridad
regional o nacional competente. HallyuHub no afirma tener acuerdos especiales
con ninguna autoridad y no automatiza el envío mientras no exista una
integración aprobada.

El registro interno debe incluir fecha, responsable, autoridad o canal usado,
referencia del reporte y resultado del escalamiento, sin copiar material ilegal
ni exponerlo en el cliente.

## Contacto de seguridad infantil

Contacto operativo designado para seguridad infantil:

`leopaletta9@gmail.com`

Este canal debe ser monitoreado por la persona responsable de revisar y
escalar reportes críticos. No enviar contraseñas ni material ilegal por email.

