# TaskCheck --- Especificación maestra del proyecto

**Tipo de producto:** aplicación de escritorio para gestión personal de
tareas\
**Nombre visible:** TaskCheck\
**Nombre técnico:** `task_check`\
**Identificador de aplicación:** `com.taskcheck.task_check`\
**Plataforma inicial:** Linux x64\
**Framework:** Flutter Desktop / Dart\
**Idioma inicial de la interfaz:** español\
**Conectividad:** funcionamiento local y offline por defecto\
**Tema:** claro y oscuro, con selector manual y opción de seguir el
sistema\
**Widget:** ventana flotante independiente\
**Estado del documento:** especificación funcional, técnica, visual y de
calidad para implementación completa

------------------------------------------------------------------------

# 1. Instrucción principal para la IA desarrolladora

Actúa como arquitecto de software, desarrollador senior de Flutter
Desktop para Linux, diseñador UX/UI y responsable de QA.

Debes **construir el proyecto completo y funcional TaskCheck**, no
limitarte a proponer una arquitectura, generar ejemplos aislados,
escribir pseudocódigo o dejar pantallas de demostración. Inspecciona el
repositorio y el entorno antes de modificarlo. Implementa todas las
funcionalidades descritas, integra la persistencia real, crea las
pruebas automatizadas y verifica el resultado mediante análisis
estático, tests y compilación Linux.

## Reglas obligatorias

1.  No afirmes que una funcionalidad está terminada si solo existe su
    interfaz visual.
2.  No uses datos ficticios en la aplicación final. Puedes usar datos de
    ejemplo exclusivamente en tests o en una opción explícita de
    demostración.
3.  No dejes botones, menús, filtros, formularios ni acciones sin
    implementar. Si una función no puede completarse por una limitación
    técnica real, documenta la limitación y ofrece una alternativa
    funcional.
4.  No uses pseudocódigo, `TODO`, `FIXME`, métodos vacíos,
    `throw UnimplementedError()` ni callbacks sin comportamiento en
    funcionalidades requeridas.
5.  No ocultes errores con bloques `catch` vacíos ni conviertas fallos
    de persistencia en éxitos aparentes.
6.  Mantén una arquitectura modular, tipada, mantenible y testeable.
    Evita concentrar la lógica en `main.dart` o en widgets enormes.
7.  Usa versiones de dependencias compatibles entre sí y con la versión
    de Flutter instalada. No inventes versiones. Comprueba las APIs
    actuales de cada paquete instalado.
8.  No agregues dependencias por comodidad si Flutter o una dependencia
    ya instalada resuelve el problema.
9.  No introduzcas servicios cloud, cuentas, telemetría, publicidad,
    suscripciones ni backend. La primera versión es local y offline.
10. Todas las operaciones CRUD deben persistir en SQLite y sobrevivir al
    cierre y reinicio de la aplicación.
11. La aplicación debe ser accesible por teclado y mostrar estados
    vacíos, de carga y de error cuando corresponda.
12. Antes de terminar, ejecuta y corrige los fallos de `dart format`,
    `flutter analyze`, todas las pruebas y la compilación Linux.
13. No elimines ni sobrescribas archivos existentes sin inspeccionarlos.
    Si el repositorio ya contiene trabajo, intégralo cuidadosamente.
14. Si hay una decisión técnica no especificada, elige la alternativa
    más sencilla, estable y mantenible que respete este documento.
    Documenta la decisión.
15. No detengas el trabajo después de crear el esqueleto. Completa la
    aplicación y sus pruebas.

## Criterio de finalización

El proyecto solo se considera entregado cuando:

-   Se puede compilar y ejecutar en Linux.
-   Las tareas, subtareas, categorías y preferencias se guardan en
    SQLite.
-   Las funcionalidades descritas funcionan de extremo a extremo.
-   El widget flotante abre como ventana independiente y puede consultar
    y modificar los mismos datos.
-   Los temas claro y oscuro funcionan.
-   Las pruebas unitarias, de widgets e integración relevantes pasan.
-   `flutter analyze` no presenta errores ni advertencias relevantes sin
    justificar.
-   `dart format` no produce cambios pendientes.
-   Se genera un paquete o instrucciones reproducibles para ejecutar y
    distribuir la aplicación.
-   Existe documentación para instalación, ejecución, pruebas,
    arquitectura, base de datos y limitaciones del widget.

------------------------------------------------------------------------

# 2. Visión del producto

TaskCheck es una aplicación de productividad personal para organizar
tareas de programación, trabajo y vida diaria. Debe permitir crear y
administrar tareas, dividirlas en subtareas, establecer prioridades,
seguir el progreso, archivar elementos y consultar rápidamente las
tareas desde una pequeña ventana flotante del escritorio.

La experiencia debe ser rápida, clara, agradable y práctica para uso
diario. No debe parecer una aplicación móvil estirada en una pantalla de
escritorio ni una plantilla genérica de Flutter.

## Principios del producto

-   **Local-first:** los datos pertenecen al usuario y se almacenan
    localmente.
-   **Offline-first:** todas las funciones principales trabajan sin
    Internet.
-   **Rápida:** operaciones habituales con pocos clics y sin pantallas
    innecesarias.
-   **Clara:** jerarquía visual, estados y prioridades fáciles de
    reconocer.
-   **Consistente:** la aplicación principal y el widget comparten
    lógica y datos.
-   **Extensible:** arquitectura preparada para futuras plataformas y
    funciones, sin implementarlas prematuramente.

------------------------------------------------------------------------

# 3. Plataforma y compatibilidad

## Requisito inicial

-   Linux de escritorio, arquitectura x64.
-   Debe funcionar en diferentes entornos de escritorio siempre que sus
    capacidades lo permitan: GNOME, KDE Plasma, XFCE y otros gestores de
    ventanas compatibles.
-   No asumir que todos los entornos ofrecen las mismas funciones de
    ventanas flotantes, bandeja o inicio automático.
-   Detectar y documentar las diferencias reales.

## Widget flotante

El widget será una **segunda ventana de escritorio independiente**, no
un panel simulado dentro de la ventana principal.

Debe:

-   Abrirse desde la aplicación principal.
-   Poder mostrarse y ocultarse sin cerrar la aplicación principal.
-   Mantenerse encima de otras ventanas cuando el gestor de ventanas lo
    permita.
-   Poder moverse y redimensionarse.
-   Recordar posición y tamaño entre sesiones cuando sea posible.
-   Tener una apariencia compacta y legible.
-   Permitir marcar tareas como completadas.
-   Permitir abrir el detalle de una tarea en la aplicación principal.
-   Mostrar cambios realizados en la aplicación principal y viceversa.
-   Compartir la misma base de datos y reglas de negocio.
-   Evitar abrir múltiples instancias innecesarias del widget.
-   Mostrar un mensaje o comportamiento alternativo si el entorno no
    admite alguna característica.

Investiga y verifica la compatibilidad de `desktop_multi_window` y
`window_manager` con la versión de Flutter y Linux utilizada. No
supongas que los plugins comparten automáticamente memoria, conexiones
SQLite o estado de Riverpod entre procesos/ventanas.

**Importante sobre consistencia:** si las ventanas se ejecutan en
isolates o engines separados, utiliza una estrategia explícita de
sincronización. Puede ser una base SQLite común con conexiones
independientes y notificaciones entre ventanas, o un mecanismo IPC
adecuado. No mantengas dos estados independientes que puedan divergir.
Implementa pruebas de sincronización.

No prometas integración nativa como extensión de GNOME/KDE: el alcance
es una ventana flotante multiplataforma dentro de Linux. La integración
nativa del escritorio puede quedar para una versión futura.

------------------------------------------------------------------------

# 4. Stack tecnológico

Utiliza estas tecnologías salvo incompatibilidad comprobada:

  -----------------------------------------------------------------------
  Área                                Tecnología
  ----------------------------------- -----------------------------------
  UI                                  Flutter Desktop

  Lenguaje                            Dart

  Estado                              Riverpod (`flutter_riverpod`)

  Navegación                          GoRouter

  Persistencia                        SQLite

  ORM y consultas reactivas           Drift

  Generación                          `drift_dev` + `build_runner`

  Rutas locales                       `path_provider` + `path`

  Ventanas                            `window_manager`

  Ventana secundaria                  `desktop_multi_window`, si su
                                      compatibilidad se verifica

  Preferencias simples                `shared_preferences`

  Identificadores                     `uuid`

  Fechas y formatos                   `intl`

  Gráficos                            `fl_chart`, solo si se utiliza en
                                      estadísticas
  -----------------------------------------------------------------------

No agregues Firebase, Supabase, servidores, APIs remotas ni
autenticación.

## Arquitectura

Usa **Feature First + Clean Architecture pragmática**.

-   `presentation`: pantallas, componentes, controladores y providers.
-   `domain`: entidades, contratos de repositorio y casos de uso cuando
    aporten valor.
-   `data`: tablas Drift, DTOs, mappers y repositorios concretos.
-   `core`: base de datos, navegación, temas, utilidades, errores y
    componentes compartidos.

Evita capas ceremoniales que solo reenvían llamadas sin aportar
separación o testabilidad.

------------------------------------------------------------------------

# 5. Estructura de carpetas esperada

Adapta los nombres si Flutter o Drift requieren convenciones
específicas, pero conserva la separación por módulos.

``` text
task_check/
├── assets/
│   ├── icons/
│   ├── images/
│   └── fonts/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/
│   │   ├── database/
│   │   ├── errors/
│   │   ├── router/
│   │   ├── theme/
│   │   ├── utils/
│   │   └── widgets/
│   ├── features/
│   │   ├── dashboard/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── tasks/
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   ├── subtasks/
│   │   ├── categories/
│   │   ├── archive/
│   │   ├── statistics/
│   │   ├── desktop_widget/
│   │   └── settings/
│   └── shared/
│       ├── models/
│       └── widgets/
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
├── linux/
├── pubspec.yaml
├── analysis_options.yaml
├── README.md
└── CHANGELOG.md
```

No es obligatorio crear archivos vacíos para todas las carpetas. Crea
los archivos necesarios para una implementación real.

------------------------------------------------------------------------

# 6. Diseño UX/UI

## Dirección visual

Diseña una aplicación de escritorio moderna, minimalista y profesional.
Debe transmitir productividad y claridad, con una interfaz cuidada y
personalidad visual propia.

Características:

-   Diseño desktop-first.
-   Sidebar lateral fija o adaptable.
-   Área de contenido amplia.
-   Paneles y tarjetas con jerarquía visual clara.
-   Espaciado consistente.
-   Esquinas suavemente redondeadas, sin abusar de tarjetas.
-   Iconografía coherente.
-   Animaciones breves y discretas.
-   Transiciones fluidas.
-   Estados hover, focus, selected y disabled.
-   Contraste suficiente y tipografía legible.
-   No utilizar emojis como sustitutos de iconos de interfaz.
-   Evitar saturación de colores, sombras exageradas y gradientes
    decorativos sin función.

Usa Material 3 como base de componentes, personalizando el tema para
conseguir una identidad visual propia. Los colores deben centralizarse
en `ColorScheme`/tokens; no dispersar valores hexadecimales por las
pantallas.

## Temas

Implementar:

1.  Claro.
2.  Oscuro.
3.  Seguir el sistema.

El selector debe estar disponible en Configuración. La selección se
persiste y se restaura al reiniciar.

Todos los componentes, diálogos, menús, formularios, gráficos y ventanas
deben respetar el tema. El widget también debe utilizar el tema elegido,
salvo que se defina una preferencia independiente en el futuro.

## Diseño adaptable

La interfaz debe adaptarse al ancho de la ventana:

-   En ventanas amplias: sidebar completa y contenido espacioso.
-   En ventanas medianas: sidebar compacta o colapsable.
-   En ventanas estrechas: navegación adaptada, sin overflow horizontal.
-   Formularios y diálogos deben respetar el tamaño disponible.
-   El widget debe tener un layout específico compacto.

No diseñar exclusivamente para una resolución fija.

## Accesibilidad y teclado

-   Tooltips en iconos sin texto.
-   Foco visible.
-   Orden de tabulación lógico.
-   Controles accesibles con teclado.
-   Contraste adecuado.
-   Etiquetas semánticas donde corresponda.
-   Atajos de teclado documentados.
-   No depender exclusivamente del color para comunicar prioridad o
    estado.

------------------------------------------------------------------------

# 7. Navegación principal

La navegación lateral debe incluir:

1.  Inicio.
2.  Mi día.
3.  Todas las tareas.
4.  Próximas.
5.  Importantes.
6.  En progreso.
7.  Completadas.
8.  Archivadas.
9.  Categorías.
10. Estadísticas.
11. Configuración.

Incluye:

-   Botón destacado para crear tarea.
-   Buscador global.
-   Indicadores numéricos útiles, por ejemplo cantidad de tareas
    pendientes.
-   Estado activo claro en la navegación.
-   Diseño consistente en todas las rutas.

No muestres enlaces que no tengan pantalla o comportamiento
implementado.

------------------------------------------------------------------------

# 8. Funcionalidades de tareas

Una tarea debe poder crearse, consultarse, editarse, completarse,
reabrirse, archivarse y eliminarse.

## Campos de una tarea

  Campo                    Tipo / regla
  ------------------------ ------------------------------------
  ID                       UUID, único
  Título                   Obligatorio, no vacío
  Descripción              Opcional, texto multilínea
  Prioridad                Baja, normal, alta, urgente
  Estado                   Pendiente, en progreso, completada
  Categoría                Opcional
  Fecha de creación        Automática
  Fecha de actualización   Automática
  Fecha límite             Opcional
  Fecha de finalización    Automática al completar
  Archivada                Booleano
  Orden                    Número para ordenar manualmente

No confundir tarea completada con tarea archivada. Archivar no debe
marcarla como completada. Una tarea archivada debe poder restaurarse.

## Prioridades

Cuatro niveles:

-   Baja.
-   Normal.
-   Alta.
-   Urgente.

Cada nivel debe tener un indicador visual y textual. Los colores deben
ser consistentes en toda la aplicación y accesibles.

## Estados

-   Pendiente.
-   En progreso.
-   Completada.

Reglas:

-   Al crear una tarea, estado inicial pendiente.
-   El usuario puede cambiar el estado manualmente.
-   Al completar, registrar `completed_at`.
-   Al reabrir, limpiar `completed_at`.
-   Completar una tarea no debe eliminar sus subtareas.
-   No marcar automáticamente como completada una tarea solo porque
    todas sus subtareas estén completas, a menos que el usuario active
    explícitamente esa preferencia. Por defecto, el estado de la tarea
    principal se controla de forma independiente.
-   Una tarea completada puede reabrirse.
-   Una tarea archivada puede restaurarse conservando sus datos.

## Operaciones

-   Crear desde botón principal.
-   Crear desde atajo de teclado.
-   Editar desde detalle o menú contextual.
-   Completar/reabrir desde lista y detalle.
-   Archivar/restaurar.
-   Eliminar con confirmación.
-   Duplicar tarea, si se implementa, debe crear un nuevo UUID y no
    copiar estados de finalización accidentalmente.
-   Ordenar y filtrar.
-   Buscar por título y descripción.

## Validaciones

-   Título obligatorio.
-   Eliminar espacios sobrantes al principio y final del título.
-   Mostrar errores cerca del campo.
-   No perder datos al cerrar accidentalmente un diálogo con cambios sin
    guardar: advertir o definir una política clara.
-   Fechas válidas y formatos localizados.
-   Manejar correctamente zonas horarias y fechas límite.

------------------------------------------------------------------------

# 9. Subtareas y progreso

Cada tarea puede tener cero o muchas subtareas.

## Campos de una subtarea

-   ID UUID.
-   `task_id` obligatorio.
-   Título obligatorio.
-   Estado completado/no completado.
-   Fecha de creación.
-   Fecha de finalización.
-   Orden.

## Operaciones

-   Crear subtarea.
-   Editar título.
-   Marcar completada.
-   Reabrir.
-   Eliminar con confirmación cuando corresponda.
-   Reordenar.
-   Mostrar lista dentro del detalle de la tarea.
-   Permitir completar desde una vista compacta cuando sea práctico.

## Cálculo de progreso

Si la tarea tiene subtareas:

`progreso = subtareas_completadas / total_subtareas * 100`

-   Si no tiene subtareas, no mostrar una barra engañosa; mostrar el
    estado de la tarea.
-   Si tiene subtareas, mostrar porcentaje y contador
    `completadas / total`.
-   Actualizar el progreso inmediatamente al modificar subtareas.
-   Una lista vacía no debe provocar división por cero.
-   No guardar un porcentaje duplicado si puede calcularse de forma
    fiable a partir de los registros.

Ejemplo visual:

``` text
Implementar autenticación                 Alta
██████████░░░░░░░░░░  50%
2 de 4 subtareas

[x] Crear modelos
[x] Implementar repositorio
[ ] Crear pantalla de login
[ ] Validar credenciales
```

------------------------------------------------------------------------

# 10. Categorías y etiquetas

## Categorías

El usuario puede:

-   Crear categorías.
-   Cambiar nombre.
-   Elegir un color.
-   Asignar categoría a una tarea.
-   Filtrar tareas por categoría.
-   Eliminar una categoría con una política segura.

Al eliminar una categoría, no eliminar sus tareas. Dejar la categoría de
esas tareas como nula o permitir reasignarlas antes de eliminar.

Categorías iniciales opcionales: Programación, Trabajo, Personal,
Estudios. Si se crean automáticamente, el usuario debe poder
modificarlas o eliminarlas.

## Etiquetas

Las etiquetas son opcionales para la primera versión, pero la estructura
debe permitir varias etiquetas por tarea si se implementan.

No confundir categoría única con etiquetas múltiples.

------------------------------------------------------------------------

# 11. Vistas y filtros

## Inicio / Dashboard

Mostrar un resumen útil y accionable:

-   Saludo y fecha actual.
-   Total de tareas pendientes.
-   Tareas en progreso.
-   Tareas completadas.
-   Tareas vencidas.
-   Tareas importantes/urgentes.
-   Tareas próximas a vencer.
-   Lista de tareas recientes o prioritarias.
-   Acceso rápido a crear tarea.

Los números deben proceder de SQLite, no ser valores fijos.

## Mi día

Mostrar tareas que vencen hoy y tareas seleccionadas para hoy si se
implementa el concepto de planificación diaria. No incluir tareas
archivadas.

## Todas las tareas

-   Listado completo de tareas no archivadas.
-   Búsqueda.
-   Filtros por estado, prioridad y categoría.
-   Orden por fecha de creación, vencimiento, prioridad y orden manual.
-   Opción de limpiar filtros.
-   Contador de resultados.

## Próximas

Mostrar tareas con fecha límite futura, ordenadas por vencimiento.

## Importantes

Mostrar tareas de prioridad alta o urgente, excluyendo archivadas y, por
defecto, completadas.

## En progreso

Mostrar tareas cuyo estado sea en progreso.

## Completadas

Mostrar tareas completadas no archivadas.

## Archivadas

Mostrar tareas archivadas y permitir restaurarlas o eliminarlas
definitivamente.

## Búsqueda

Buscar por título y descripción, sin distinguir mayúsculas/minúsculas
cuando sea posible. Debe manejar correctamente acentos según las
capacidades de SQLite y la estrategia elegida.

Todos los filtros deben combinarse de forma predecible y poder
limpiarse.

------------------------------------------------------------------------

# 12. Estadísticas

Implementar una pantalla con datos reales:

-   Total creadas.
-   Pendientes.
-   En progreso.
-   Completadas.
-   Archivadas.
-   Vencidas.
-   Tasa de finalización.
-   Tareas completadas por periodo.
-   Distribución por prioridad.
-   Distribución por categoría.

Usar gráficos sencillos, legibles y coherentes con el tema. No mostrar
gráficos vacíos como si existieran datos. Para periodos sin información,
mostrar un estado vacío explicativo.

Las estadísticas no deben contar subtareas como tareas principales salvo
que se indique expresamente.

------------------------------------------------------------------------

# 13. Ventana flotante del escritorio

El widget es un requisito central, no una pantalla decorativa.

## Contenido

-   Título TaskCheck.
-   Tareas pendientes/prioritarias.
-   Indicador de prioridad.
-   Fecha límite cuando exista.
-   Progreso de subtareas cuando corresponda.
-   Acción rápida para completar/reabrir.
-   Acción para abrir la aplicación principal.
-   Acción para actualizar o refrescar si el mecanismo reactivo lo
    requiere.

## Comportamiento

-   Abrir/cerrar desde la aplicación.
-   Recordar visibilidad si es técnicamente seguro.
-   Recordar posición y tamaño.
-   Mantenerse encima cuando el sistema lo permita.
-   No robar foco continuamente.
-   Evitar que quede fuera de pantalla después de cambiar resolución o
    monitor.
-   Tener tamaño mínimo razonable.
-   No permitir que el contenido se desborde.
-   Adaptarse a claro y oscuro.
-   Comunicar errores de acceso a la base de datos.
-   Compartir datos con la ventana principal.

## Limitaciones y validación

Prueba en el entorno Linux disponible y documenta qué funciona en
GNOME/KDE/XFCE. No declares compatibilidad universal sin pruebas.

La ventana flotante debe ser funcional aunque el escritorio no ofrezca
una bandeja del sistema. No hagas que la bandeja sea requisito para
acceder al widget.

Si una característica como `alwaysOnTop` no está soportada por un gestor
de ventanas, informa la limitación y conserva la ventana como ventana
independiente normal.

------------------------------------------------------------------------

# 14. Base de datos y persistencia

Utiliza Drift sobre SQLite.

## Tablas mínimas

### `tasks`

-   `id`: texto UUID, clave primaria.
-   `title`: texto no nulo.
-   `description`: texto nullable.
-   `priority`: entero o enum serializado con mapping estable.
-   `status`: entero o enum serializado con mapping estable.
-   `category_id`: nullable, clave foránea.
-   `due_date`: fecha/hora nullable, almacenamiento consistente.
-   `created_at`: fecha/hora.
-   `updated_at`: fecha/hora.
-   `completed_at`: nullable.
-   `is_archived`: booleano.
-   `sort_order`: entero.

### `subtasks`

-   `id`: texto UUID, clave primaria.
-   `task_id`: clave foránea a tasks.
-   `title`: texto no nulo.
-   `is_completed`: booleano.
-   `created_at`: fecha/hora.
-   `completed_at`: nullable.
-   `sort_order`: entero.

### `categories`

-   `id`: texto UUID, clave primaria.
-   `name`: texto no nulo.
-   `color`: representación estable del color.
-   `created_at`.
-   `updated_at`.

### `tags` y `task_tags`

Solo si se implementan etiquetas múltiples.

## Reglas de integridad

-   Activar claves foráneas de SQLite.
-   Definir índices para consultas frecuentes: estado, prioridad,
    vencimiento, categoría, archivado y relación de subtareas.
-   Eliminar subtareas al eliminar definitivamente su tarea mediante
    cascada o transacción controlada.
-   Eliminar categoría no debe borrar tareas.
-   Utilizar transacciones para operaciones que modifiquen varios
    registros.
-   Evitar duplicados accidentales.
-   Usar migraciones versionadas de Drift.
-   No borrar la base de datos para resolver cambios de esquema.
-   Crear pruebas de migración.
-   Guardar la base de datos en una ubicación apropiada del directorio
    de datos del usuario, obtenida mediante `path_provider`.
-   No guardar la base de datos dentro del directorio de instalación de
    la aplicación.

## Backups

Implementar exportación e importación JSON como funcionalidad de
respaldo si es viable en el alcance final:

-   Exportar tareas, subtareas, categorías y preferencias relevantes.
-   Validar el archivo antes de importar.
-   Evitar duplicados por UUID.
-   Permitir estrategia de reemplazo o combinación claramente explicada.
-   Hacer la importación en transacción.
-   No sobrescribir datos sin confirmación.
-   Probar archivos inválidos, incompletos y de versiones anteriores.

------------------------------------------------------------------------

# 15. Preferencias

Persistir como mínimo:

-   Tema: sistema/claro/oscuro.
-   Preferencia de ordenación.
-   Filtros o vista inicial, si aporta valor.
-   Posición y tamaño de la ventana flotante.
-   Preferencia de visibilidad del widget.
-   Configuración de notificaciones si se implementan.

Usar `shared_preferences` para preferencias simples. La información de
tareas debe permanecer en SQLite.

------------------------------------------------------------------------

# 16. Notificaciones y recordatorios

Si se incluyen en esta entrega:

-   Notificaciones locales para tareas con fecha límite.
-   Recordatorios configurables.
-   No enviar notificaciones duplicadas.
-   Manejar permisos y diferencias entre entornos Linux.
-   No afirmar que funcionan en todos los entornos sin probar el backend
    de notificaciones utilizado.
-   Si no se puede garantizar una notificación nativa, implementar una
    alternativa documentada o dejar esta función claramente fuera del
    alcance inicial, sin mostrar controles falsos.

Las tareas y el widget no deben depender de las notificaciones.

------------------------------------------------------------------------

# 17. Atajos de teclado

Implementar y documentar atajos razonables:

-   `Ctrl+N`: nueva tarea.
-   `Ctrl+F`: buscar.
-   `Ctrl+,`: configuración, si no entra en conflicto con el sistema.
-   `Esc`: cerrar diálogo o limpiar búsqueda según el contexto.
-   `Enter`: confirmar formularios cuando sea seguro.
-   `Ctrl+Enter`: guardar tarea desde el editor, si es consistente.
-   `Delete`: eliminar solo cuando exista una selección clara y
    confirmación adecuada.

No ejecutar acciones destructivas sin contexto o confirmación.

------------------------------------------------------------------------

# 18. Calidad de código

-   Null safety.
-   Tipos explícitos donde aporten claridad.
-   Widgets pequeños y reutilizables.
-   Separación entre UI y lógica de negocio.
-   Providers con ciclo de vida correcto.
-   Manejo centralizado de errores.
-   Repositorios testeables.
-   Evitar `dynamic` salvo necesidad justificada.
-   Evitar lógica de base de datos dentro de widgets.
-   Evitar consultas repetidas innecesarias.
-   Evitar rebuilds excesivos.
-   Usar streams de Drift/Riverpod de forma apropiada.
-   Mantener consistencia en nombres y convenciones.
-   Documentar decisiones no obvias.
-   No ignorar excepciones silenciosamente.

Configura `analysis_options.yaml` con reglas útiles y razonables. No
desactives reglas para ocultar problemas.

------------------------------------------------------------------------

# 19. Plan obligatorio de pruebas

No basta con que la aplicación abra. Deben probarse reglas de negocio,
persistencia, interfaz y compilación.

## 19.1 Unit tests

Como mínimo:

### Tareas

-   Crear tarea válida.
-   Rechazar título vacío.
-   Recortar espacios del título.
-   Actualizar tarea.
-   Completar tarea y establecer fecha de finalización.
-   Reabrir tarea y limpiar fecha de finalización.
-   Archivar sin completar.
-   Restaurar sin perder datos.
-   Eliminar definitivamente.
-   Ordenar por prioridad.
-   Filtrar por estado y fecha.

### Subtareas

-   Crear subtarea.
-   Rechazar título vacío.
-   Editar.
-   Completar.
-   Reabrir.
-   Eliminar.
-   Calcular progreso con cero subtareas.
-   Calcular progreso con todas pendientes.
-   Calcular progreso parcial.
-   Calcular progreso con todas completadas.
-   Verificar que el progreso se actualiza después de una modificación.

### Categorías

-   Crear.
-   Renombrar.
-   Cambiar color.
-   Eliminar sin borrar tareas.
-   Verificar comportamiento de tareas sin categoría.

### Reglas de fechas

-   Tarea sin fecha límite.
-   Tarea que vence hoy.
-   Tarea futura.
-   Tarea vencida.
-   Cambios de día y formato local.

## 19.2 Tests de base de datos

-   Inserción y lectura.
-   Actualización.
-   Eliminación.
-   Relaciones tarea-subtareas.
-   Claves foráneas.
-   Cascadas o transacciones.
-   Consultas de filtros.
-   Streams reactivos.
-   Migraciones.
-   Persistencia después de cerrar y reabrir la conexión.

## 19.3 Widget tests

Probar:

-   Dashboard.
-   Navegación.
-   Lista de tareas.
-   Formulario de creación.
-   Formulario de edición.
-   Validación de título.
-   Selector de prioridad.
-   Selector de categoría.
-   Detalle de tarea.
-   Lista de subtareas.
-   Barra de progreso.
-   Cambio de tema.
-   Estados vacíos.
-   Errores.
-   Diseño con diferentes tamaños de ventana.

## 19.4 Integration tests

Probar flujos completos:

1.  Abrir aplicación.
2.  Crear categoría.
3.  Crear tarea asignada a la categoría.
4.  Añadir varias subtareas.
5.  Completar algunas.
6.  Verificar progreso.
7.  Cerrar y volver a abrir.
8.  Comprobar que los datos persisten.
9.  Completar tarea.
10. Reabrir tarea.
11. Archivar y restaurar.
12. Abrir widget flotante.
13. Completar una tarea desde el widget.
14. Verificar actualización en la ventana principal.
15. Cambiar tema y comprobar persistencia.

Si el entorno de CI no permite probar una ventana gráfica real, separar
las pruebas de integración de lógica de las pruebas manuales de ventana
y documentar esa limitación.

## 19.5 Comandos de verificación

Ejecutar:

``` bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
flutter build linux --release
```

Ajustar los comandos de integración según la configuración real del
proyecto. No declarar tests ejecutados si no se han ejecutado.

------------------------------------------------------------------------

# 20. Rendimiento y robustez

-   La aplicación debe iniciar sin conexión.
-   No bloquear el hilo de UI con operaciones pesadas.
-   Usar consultas eficientes e índices.
-   No cargar todo el historial si solo se necesita una vista filtrada.
-   Gestionar correctamente cierres de ventanas y conexiones de base de
    datos.
-   Evitar pérdida de datos por cierres normales.
-   Manejar fallos de escritura con mensajes claros.
-   Validar importaciones antes de modificar la base de datos.
-   No crear múltiples instancias de la ventana flotante.
-   Evitar fugas de streams, subscriptions y controllers.
-   Mantener una cantidad razonable de dependencias.

------------------------------------------------------------------------

# 21. Entregables

La IA debe entregar:

1.  Código fuente completo de TaskCheck.
2.  Proyecto Flutter Linux compilable.
3.  Interfaz completa, no wireframes.
4.  Persistencia SQLite funcional.
5.  CRUD de tareas y subtareas.
6.  Categorías y filtros.
7.  Archivado y restauración.
8.  Dashboard y estadísticas reales.
9.  Temas claro, oscuro y sistema.
10. Ventana flotante independiente funcional.
11. Pruebas unitarias, de widgets e integración.
12. Migraciones de base de datos.
13. `README.md` completo.
14. `CHANGELOG.md`.
15. Instrucciones de instalación y dependencias Linux.
16. Instrucciones para ejecutar en desarrollo.
17. Instrucciones para ejecutar tests.
18. Instrucciones para generar build release.
19. Limitaciones conocidas, especialmente por entorno de escritorio.
20. Evidencia real de comandos ejecutados y resultados.

## README obligatorio

Debe explicar:

-   Qué es TaskCheck.
-   Funcionalidades.
-   Requisitos.
-   Dependencias del sistema Linux.
-   Instalación.
-   Ejecución.
-   Ubicación de los datos.
-   Arquitectura.
-   Estructura de carpetas.
-   Base de datos y migraciones.
-   Pruebas.
-   Compilación release.
-   Widget flotante y compatibilidad.
-   Resolución de problemas.

------------------------------------------------------------------------

# 22. Criterios de aceptación verificables

La implementación debe satisfacer todos estos criterios:

  ---------------------------------------------------------------------------------
  ID                      Criterio                Resultado esperado
  ----------------------- ----------------------- ---------------------------------
  TC-001                  Iniciar aplicación      Abre sin errores en Linux

  TC-002                  Crear tarea             Se guarda y aparece en la lista

  TC-003                  Validar título          No permite título vacío

  TC-004                  Editar tarea            Cambios persistidos

  TC-005                  Prioridad               Se muestra y filtra correctamente

  TC-006                  Estado                  Pendiente/en progreso/completada
                                                  funciona

  TC-007                  Subtareas               Se crean y modifican
                                                  correctamente

  TC-008                  Progreso                Porcentaje coincide con subtareas
                                                  completadas

  TC-009                  Completar               Guarda fecha de finalización

  TC-010                  Reabrir                 Recupera estado pendiente/en
                                                  progreso según regla definida

  TC-011                  Archivar                Oculta de vistas activas sin
                                                  completar

  TC-012                  Restaurar               Recupera la tarea

  TC-013                  Categorías              CRUD funcional

  TC-014                  Filtros                 Resultados correctos

  TC-015                  Búsqueda                Encuentra tareas por texto

  TC-016                  Dashboard               Datos reales de la base de datos

  TC-017                  Estadísticas            Totales correctos

  TC-018                  Tema                    Claro/oscuro/sistema persisten

  TC-019                  Widget                  Abre como ventana independiente

  TC-020                  Widget y app            Reflejan cambios mutuamente

  TC-021                  Reinicio                Datos permanecen

  TC-022                  Tests                   Suite automatizada pasa

  TC-023                  Análisis                Sin errores de análisis

  TC-024                  Release                 `flutter build linux --release`
                                                  termina correctamente
  ---------------------------------------------------------------------------------

No marcar un criterio como aprobado sin haberlo verificado.

------------------------------------------------------------------------

# 23. Orden de implementación

Trabaja en este orden, pero continúa hasta completar el producto:

## Etapa 1 --- Inspección y configuración

-   Inspeccionar Flutter, Dart y Linux.
-   Verificar dependencias y plugins.
-   Crear/configurar proyecto.
-   Configurar análisis estático.
-   Establecer estructura.

## Etapa 2 --- Fundamentos

-   Tema y tokens visuales.
-   Navegación.
-   Base de datos Drift.
-   Migraciones.
-   Providers y repositorios.
-   Manejo de errores.

## Etapa 3 --- Interfaz principal

-   Sidebar.
-   Dashboard.
-   Componentes comunes.
-   Buscador.
-   Formularios y diálogos.

## Etapa 4 --- Gestión de tareas

-   CRUD.
-   Prioridades.
-   Estados.
-   Fechas.
-   Categorías.
-   Filtros y búsqueda.

## Etapa 5 --- Subtareas

-   CRUD.
-   Orden.
-   Progreso reactivo.
-   Pruebas de reglas.

## Etapa 6 --- Archivo y estadísticas

-   Archivar/restaurar.
-   Completadas.
-   Dashboard real.
-   Gráficos y métricas.

## Etapa 7 --- Widget flotante

-   Segunda ventana.
-   Persistencia de posición/tamaño.
-   Sincronización.
-   Acciones rápidas.
-   Pruebas y documentación de compatibilidad.

## Etapa 8 --- Calidad y entrega

-   Atajos.
-   Accesibilidad.
-   Estados vacíos y errores.
-   Pruebas completas.
-   Correcciones.
-   Build release.
-   README y changelog.

------------------------------------------------------------------------

# 24. Protocolo de trabajo de la IA

Antes de escribir código:

1.  Inspecciona los archivos existentes.
2.  Comprueba versiones de Flutter y Dart.
3.  Comprueba las dependencias y su compatibilidad con Linux.
4.  Identifica limitaciones de plugins de múltiples ventanas.
5.  Presenta un plan breve y después comienza la implementación.

Durante el desarrollo:

-   Trabaja directamente en el repositorio.
-   Crea archivos completos y coherentes.
-   Ejecuta generación de código cuando Drift lo requiera.
-   Después de cada módulo, ejecuta análisis y pruebas relevantes.
-   Corrige errores antes de continuar.
-   Mantén el documento de decisiones técnicas actualizado.
-   No reemplaces funcionalidad ya implementada por mocks.
-   No pidas confirmación para decisiones técnicas menores que este
    documento permite resolver.

Al finalizar:

1.  Ejecuta formato.
2.  Ejecuta análisis estático.
3.  Ejecuta todos los tests posibles.
4.  Compila Linux en release.
5.  Revisa los criterios de aceptación uno por uno.
6.  Entrega un resumen de funcionalidades verificadas.
7.  Enumera con honestidad cualquier criterio no completado o limitación
    ambiental.
8.  Proporciona los comandos exactos para ejecutar y compilar el
    proyecto.

**Objetivo final: entregar una aplicación de escritorio Linux llamada
TaskCheck, completa, visualmente pulida, funcional, persistente,
testeada y lista para utilizar. No entregar solamente una demostración
ni un prototipo.**
