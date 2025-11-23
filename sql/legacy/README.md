# Legacy SQL scripts (pre-restructure)

Estos archivos conservan los nombres originales que existían en la raíz de `sql/`.
Se mantienen solo como referencia o compatibilidad, pero la versión mantenida y
comentada de cada script vive en las carpetas organizadas:

- **`sql/oltp/`**: enriquecimiento transaccional (CIUDAD, FK en CLIENTES, tablas de
  provincias/cantones/parroquias y asignación de ciudades).
- **`sql/dw/`**: definición del esquema estrella y vista de producto más vendido.

Si necesitas mantener la nomenclatura antigua para un pipeline existente, usa
estos archivos; para nuevas implementaciones ejecuta los scripts de `sql/oltp`
y `sql/dw` que contienen comentarios detallados y estructura actualizada.
