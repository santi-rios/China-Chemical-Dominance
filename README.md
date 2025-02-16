
## Mak Plank Servers

- [Fuente](https://www.fkf.mpg.de/edv)
- [Computing and Databases Services](https://www.cbs.mpg.de/methods-and-development-groups/databases-and-it)
- [IT group](https://www.molgen.mpg.de/en/it)
- [Max Planck Institute for Software Systems](https://www.mpi-sws.org/)
- [IT Services at the Institute](https://www.mr.mpg.de/facilities/it)
  - Networking (Internet Connection, Firewall, LAN, WLAN, VLAN, VPN)
  - Directory Access- and Naming Services (SSO - Single Sign On, LDAP, NIS, NIS+, RAS, DNS, DHCP, WINS)
  - Mail services (Web Mail, Calendar, Address Book, Email Clients)
  - Storage and File Services (SAN - Storage Area Network, file servers, FTP, Backup)
  - **High Performance Computing (Clusters and single-node compute servers)**
  - **Software (Software Devolopment and License Management)**
  - Database Services (MySQL, SQLite)
  - Web Services (Intranet, Collaboration Tools, Content Management, Wikis, Extranet and **WWW**)
  - [Bioinformatics Department](https://www.ie-freiburg.mpg.de/1896683/Service)
    - we also operate a range of different servers that run webservices like Galaxy and R-Studio, provide centralised home directories and logins, serve as data capture for the sequencing machines or are simply compute servers to run analysis on. Two of these compute servers (minimus, maximus) are also available to any institute member. They run on linux (CentOS) and knowledge of the command line is required to operate them. All widely used bioinformatics tools are already installed (e.g. samtools, bedtools, bowtie, macs, deepTools). 
  - [Software Workshop](https://ps.is.mpg.de/software-workshop)



### **1. Requisitos del Servidor**

#### **1.1 Sistema Operativo**

- Se recomienda **Linux (Ubuntu 20.04+ o CentOS 7+)** por estabilidad y facilidad de configuración.
- También es posible usar **Windows Server 2019+** o **MacOS**, pero Linux es la opción preferida.

#### **1.2 Especificaciones de Hardware (Mínimas Recomendadas)**

- **CPU:** 2 núcleos (recomendado 4+ si se espera alta concurrencia)
- **RAM:** 4 GB mínimo (recomendado 8+ GB si hay muchos usuarios simultáneos)
- **Espacio en disco:** 10 GB mínimo (se recomienda SSD para mejor rendimiento)
- **Conectividad:** Acceso a internet o a los repositorios de CRAN para instalar paquetes

#### **1.3 Software Requerido**
- **R (versión 4.0 o superior)**
  - Verifica que R esté instalado con `R --version`
- **RStudio Server (Opcional, pero útil para mantenimiento)**
- **Shiny Server** (Para ejecutar la aplicación como un servicio web)
- **Node.js (Opcional, si se usa bslib con funciones avanzadas de Bootstrap 5)**. Se puede instalar con:
  ```bash
  sudo apt install nodejs
  ```
  - También se puede remover las dependencias de Node.js en bslib con:
  ```r
    options(bslib.engine = "bootstrap-4")
```


### **2. Librerías de R Necesarias**

Las siguientes librerías deben estar instaladas en el servidor. Se pueden instalar ejecutando `install.packages("nombre")` en R.

- `shiny` (Para ejecutar la aplicación)
- `bslib` (Para temas de Bootstrap 5)
- `dplyr` (Para manipulación de datos)
- `plotly` (Para visualizaciones interactivas)
- `data.table` (Para manejo eficiente de datos)
- `ggplot2` (Opcional, pero útil para futuras modificaciones gráficas)

Para instalar todas de una vez en el servidor:

```r
install.packages(c("shiny", "bslib", "dplyr", "plotly", "data.table"))
```

---

### **3. Configuración del Servidor Shiny**

Si el servidor será accesible desde la red, se necesita configurar **Shiny Server**:

1. **Instalar Shiny Server**  
   - En Ubuntu:
     ```bash
     sudo apt update
     sudo apt install gdebi-core
     wget https://download3.rstudio.org/ubuntu-20.04/x86_64/shiny-server-1.5.20.1002-amd64.deb
     sudo gdebi shiny-server-1.5.20.1002-amd64.deb
     ```
   - En CentOS:
     ```bash
     sudo yum install epel-release
     sudo yum install R
     wget https://download3.rstudio.org/centos7/x86_64/shiny-server-1.5.20.1002-x86_64.rpm
     sudo yum install shiny-server-1.5.20.1002-x86_64.rpm
     ```

2. **Verificar que Shiny Server se está ejecutando**
   ```bash
   sudo systemctl status shiny-server
   ```

3. **Ubicación de la Aplicación en el Servidor**
   - Shiny Server busca aplicaciones en:  
     `/srv/shiny-server/`
   - Copiar la aplicación a esa ruta:
     ```bash
     sudo cp -r /ruta/a/tu/shiny-app /srv/shiny-server/
     ```

4. **Permisos de Usuario**
   - Asegurar que Shiny Server pueda acceder a los archivos:
     ```bash
     sudo chown -R shiny:shiny /srv/shiny-server/tu-shiny-app
     ```

---

### **4. Configuración de Acceso y Seguridad**

#### **4.1 Apertura de Puertos**
- Shiny Server por defecto usa el puerto **3838**.
- Si la aplicación debe ser accesible externamente, se necesita abrir el puerto:
  ```bash
  sudo ufw allow 3838/tcp
  ```

#### **4.2 Configuración con un Servidor Web (Opcional)**

- Para acceso HTTPS y mejor seguridad, se recomienda usar **Nginx o Apache** como proxy inverso.

Ejemplo de configuración en **Nginx** (archivo `/etc/nginx/sites-available/shiny`):
```
server {
    listen 80;
    server_name shiny.mi-dominio.com;

    location / {
        proxy_pass http://127.0.0.1:3838/;
        proxy_redirect off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```
Activar y reiniciar Nginx:
```bash
sudo ln -s /etc/nginx/sites-available/shiny /etc/nginx/sites-enabled/
sudo systemctl restart nginx
```

---

### **5. Pruebas y Mantenimiento**

- **Verificar que Shiny Server esté activo**  
  ```bash
  sudo systemctl status shiny-server
  ```
- **Probar la aplicación accediendo a:**  
  ```
  http://IP_DEL_SERVIDOR:3838/tu-shiny-app
  ```
- **Revisar logs de errores si hay problemas:**  
  ```bash
  sudo journalctl -u shiny-server --no-pager | tail -n 50
  ```

---

### **6. Consideraciones Finales**

✅ **Factores clave a consultar con IT:**
1. **¿El servidor tiene R y Shiny Server instalados o pueden instalarse?**
2. **¿Se permite abrir el puerto 3838 o configurar un proxy inverso?**
3. **¿Se dispone de suficiente memoria RAM y CPU para ejecutar la aplicación con múltiples usuarios?**
4. **¿Cómo se manejará la seguridad del acceso a la aplicación?** (¿VPN, autenticación, etc.?)
5. **¿Se permite instalar las librerías necesarias?**
6. **¿Se puede configurar un dominio (ejemplo: `shiny.mi-universidad.edu`) para acceder fácilmente?**

---

📌 **Resumen de Requisitos Técnicos**
| Recurso       | Especificación Mínima |
|--------------|----------------------|
| **SO**       | Linux (Ubuntu 20.04+) o Windows Server 2019+ |
| **CPU**      | 2 núcleos (4 recomendados) |
| **RAM**      | 4 GB mínimo (8+ GB recomendado) |
| **Disco**    | 10 GB SSD mínimo |
| **R versión**| 4.0 o superior |
| **Shiny Server** | Instalado y configurado |
| **Puertos abiertos** | 3838 (o configuración de proxy inverso) |
| **Navegador compatible** | Chrome, Firefox, Edge |

---


## Otras soluciones de Shiny Server

https://shiny.posit.co/r/deploy.html
https://hosting.analythium.io/how-to-pick-the-right-hosting-option-for-your-shiny-app/
https://quarto.org/docs/publishing/netlify.html
https://www.netlify.com/pricing/

### **Alternativa 1: ShinyProxy**

- **Ventajas:**
  - Escalabilidad automática
  - Soporte para Docker
  - Autenticación integrada
  - Balanceo de carga
- **Desventajas:**
  - Configuración más compleja

### digitalocean

https://docs.digitalocean.com/products/marketplace/catalog/shinyproxy/
https://www.digitalocean.com/pricing/droplets#basic-droplets
https://hosting.analythium.io/how-to-host-shiny-apps-on-the-digitalocean-app-platform/
https://dan-carpenter.co.uk/2020/11/09/shiny-apps-on-digital-ocean/
https://deanattali.com/2015/05/09/setup-rstudio-shiny-server-digital-ocean/
https://www.marinedatascience.co/blog/2019/04/28/run-shiny-server-on-your-own-digitalocean-droplet-part-1/
https://www.digitalocean.com/community/tutorials/how-to-set-up-shiny-server-on-ubuntu-20-04
https://marketplace.digitalocean.com/apps/rstudio

### **Alternativa 2: RStudio Connect**

- **Ventajas:**
  - Integración con RStudio
  - Programación de informes
  - Programación de tareas
  - Soporte empresarial
- **Desventajas:**
  - Licencia de pago
  - Costo de mantenimiento

### 

https://www.shinyapps.io/



# Tools

https://chemrxiv.org/engage/chemrxiv/article-details/67920ada6dde43c908f688f6

https://chemrxiv.org/engage/api-gateway/chemrxiv/assets/orp/resource/item/67920ada6dde43c908f688f6/original/china-s-rise-in-the-chemical-space-and-the-decline-of-us-influence.pdf