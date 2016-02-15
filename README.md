** MIGRACIÓN **

Introducción:

La migración debería de ser transparente de la nueva versión Dspace 5.4 pero las estadísticas se quedan atrás cuando la versión a migrar es muy antigua (en nuestro caso 1.7), aunque también están contempladas en la actualización.

Al utilizar el docker de “quantumobject”, es sistema nos la encontramos instalada, por lo que realizamos el procedimiento de actualización MANUAL y no la instalación con la actualización, ya que en este punto de ejecución NO tenemos los datos necesarios del ORIGEN (BBDD, Solr y Logs).

Hemos seguido la documentación de actualización manual y ha funcionado todo menos la migración de las estadísticas por lo que hemos tenido que realizar el procedimiento en dos etapas: la primera desde 1.7 a 3.5 y la segunda de 3.5 a 5.4 (pero solo para los datos de las estadísticas de Solr).

La idea principal es hacer la migración en dos etapas con dos versiones de Dspace (la 3.5 y la 5.4, sugerida por José Vicente Ribelles Aguilar de riunet.upv.es) con lo que crearemos dos imágenes docker: una de ellas con la versión de Dspace 3.5 para realizar la migración de los datos de Solr de 1.7 a 3.5 y la segunda imagen con Dspace 5.4 para la migración de los datos de  Solr de 3.5 a 5.4.

Las versiones de DSpace las hemos incluido en los archivos Dockerfiles. Las versiones las podemos encontrar en https://github.com/DSpace/DSpace/releases.

Una vez realizada todas las operaciones, tendremos el docker54 con la actualización disponible para hacer el deploy de la aplicación (webapps) en cualquier host (con las mismas versiones de las aplicaciones utilizadas en el docker) o en este mismo docker. 

José Checa Claudel. Febrero 2016.


1.- Generación de las imágenes necesarias en dockers:

	- Basados en https://github.com/QuantumObject/docker-dspace del MAINTAINER Angel Rodriguez  "angel@quantumobject.com", con algunas adaptaciones para que no borre los sources y poder realizar adaptaciones (docker54) y servicios SOLO de Solr (docker35) para la migración intermedia.
	- Se han creado dos imágenes docker para la migración de los datos en dos etapas; los archivos para general las imágenes correspondientes están en los directorios docker-dspace35 (docker35) y docker-dspace54 (docker54).
	- Crear ambas imágenes con $docker build -t dspace54/dspace35 .
	- Ejecutar el docker necesario en cada momento ya que comparte los puertos. Para ello tenemos unos scripts de inicialización que crean el docker compartiendo el /tmp del host anfitrión a través de volúmenes (después start/stop). Utilizaremos el /tmp para mantener los datos necesarios utilizados al realizar la migración.
	- Copiar en /tmp del host anfitrión los datos necesarios de la versión ORIGEN de repositorio: el BACKUP de la BBDD (esquema.sql, y volcado dump), el directorio solr como solr17.tar y el directorio log como log17.tar.


2.- NO NECESARIO PARA LA MIGRACIÓN. Esta opción inicializa la BBDD y crea el esquema, además del usuario administrador. Para nuestro caso,donde la migración incluye la creación de otra BBDD,  importaremos el esquema y datos de la BBDD origen y en la que ya está incluido importado el usuario administrador.

	- $docker exec -ti dspace54 /bin/bash
	- $create-admin


3.- Creación de BBDD nueva para la migración en docker54.

	- En el docker docker54 (exec).
	- $/sbin/setuser dspace createdb -U <username> -E UNICODE <dbname> --lc-collate --lc-ctype (es_ES.UTF-8 - probar próxima vez, o si en las pruebas de carga hay problemas con el juego de caracteres).
	- Para comprobar: $/sbin/setuser dspace psql -l (ver los juegos de caracteres).
	- Comprobar juego de caracteres. Colation/Ctype: es_ES.UTF-8, por lo menos en la BBDD original. Verificar y a tener en cuenta.


4.- Restore de dspace17.

	- En el docker54 (exec).
	- $/sbin/setuser dspace psql <dbname> < (file_eschema.sql), desde el /tmp.
	- $/sbin/setuser pg_restore -a -v -e -Fc --disable-triggers -d <dbname.dump> < file_dump, desde el /tmp
	- $/sbin/setuser vacuumdb --analyze <dbname>


5.- DSpace a nueva BBDD

	- En el docker54 (exec).
	- Paramos Tomcat: $sv stop tomcatX (siempre que paremos tomcat, borraremos los logs de dspace, para comprobar los resultados).
	- Editamos dspace.conf (para apuntar a la nueva BBDD creada), todas las utilidades usadas a continuación se realizan sobre la nueva BBDD.


6.- Update BBDD

	- En el docker54 (exec) y con tomcatX parado.
	- $[dspace]/bin/dspace database info (para verificar que detecta nuestra versión de BBDD)
	- $/sbin/setuser dspace psql -U dspace -f [dspace]/etc/postgress/update-sequences.sql (para optimizar las “sequences”).
	- $[dspace]/bin/dspace database-migrate (para migrar)
	- Arrancamos Tomcat: $sv start tomcatX
	- En este momento, en los logs debe verse que la BBDD está OK y se arranca el sistema bien. Podemos comprobar la existencia de datos. Ojo, con los índices que se está regenerando en este momento, y los listados van actualizando los totales (artículos, usuarios, colecciones, etc.) poco a poco.


7.- Limpieza del esquema de la BBDD (no se usa más en esta versión, ni posteriores).

	- En el docker54 (exec).
	- $[dspace]/bin/dspace index-db-browse -f -b
	- $/sbin/setuser dspace psql dspace54.
			#postgress= delete from communities2item;


8.- Actualizar/Migrar Solr (search/browse).

	- $[dspace]/dspace index-discovery -f (empieza la reconversión/indexación de search/browse basado en Solr desde la BBDD. Tarda bastante +- 15 horas).
	- No sé si es necesario, ya que en el punto 6 se actualiza automáticamente (no estoy seguro)


9.- Migrar Solr (statistics). Paramos docker54 (stop).

	a.- De Solr17 a Solr35

		- Arrrancar el docker35.
		- Montar (exec) docker35 (habilitar app/solr en tomcat, modificar en la imagen).
		- Copiar todo el core de Solr/statistics de dspace17
		- Poner bien el propietario de manera recursiva al directorio cuando se copien.
		- $[dspace]/bin/dspace stats-util -o
		- Hacer .tar de los datos nuevos solo (solr/statistics/data) … estos ya están migrados a 3.5 y localizarlos en el /tmp via solr35-data.tar.
		- Para el docker35 (solo es necesario para esta actualización previa).

	b.- De Solr35 a Solr54

		- Montar docker54 (habilitar SOLO app/solr en el archivo de configuración de tomcat, server.xml). 
		- Parar tomcatX, borrar logs.
		- Copiar solr/statistics/data (sólo) de la versión 35 del paso “b” anterior.
		- Poner bien el propietario de manera recursiva al directorio cuando se copien. 
		- Iniciar tomcatX a través de: $sv start tomcatX (solo Solr)
		- Migro con: $[dspace]/bin/dspace stats-util -o
		- Consultar log y que no haya errores.
		- Habilitar TODAS las app/* en el archivos de configuraciones de tomcat, server.xml y volver a reiniicar tomcatX ya con todas las apps incluidas.

10.- Actualizar Solr

	- En este punto NO tenemos estadísticas de Solr (no lo sé seguro, comprobar), si no las hubiere habría que reindexar de nuevo (tarda bastante +- 16 h)
	- $[dspace]/bin/dspace solr-reindex-statistics 

11.- Actualizar estadísticas VIEJAS (creo que basadas en Lucene, toma los datos a procesar del directorio de log ¿ qué ficheros ?). Son las estadísticas desde administrador 

	- http://<repositorio>/xmlui/statistics - Generales
	- http://<repositorio>/xmlui/statistics?date=yyyy-mm - Particulares por mes.

	- No se aconseja utilizar las estadísticas generadas de esta forma, ya que no están sujetas a los principios modernos de detección de robots y de filtrado que se utilizan con SOLR.
	- Se generan desde el crontab a través de la utilidad $[dspace]/bin/dspace, tomando como datos de entrada los archivos ¿? en el fichero de log, para generar otros en el mismo fichero de log.
	- Con stat-general se generan/actualizan la página general de estadísticas (se reescriben los archivos de logs correspondientes)
	- Con stat-monthly se genera/actualiza la páginas mensuales (se reescriben los archivos d logs correspondientes)
	- Con stat-initial ….
	- Para migrar, basta con copiar el directorio de log de dspace17 en la nueva versión. Con esto ya saldrían las estadísticas del viejo estilo. Habría que actualizar con stat-general y los necesarios, para ponerlos al día.
	- Estas estadísticas, solo son visibles desde el Administrador.


Pepe Checa. Febrero 2016