import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  BarChart3,
  CheckCircle2,
  ClipboardList,
  KeyRound,
  LogIn,
  LogOut,
  ShieldCheck,
  RefreshCcw,
  Save,
  Search,
  Send,
  Trash2,
  UserPlus,
} from 'lucide-react';
import { API_BASE_URL, getErrorMessage } from './api/client';
import { authApi, catalogosApi, dashboardApi, solicitudesApi, usuariosApi } from './api/endpoints';
import { useAsync } from './hooks/useAsync';
import { useForm } from './hooks/useForm';
import { currency, dateTime } from './utils/format';

const views = [
  { id: 'auth', label: 'Acceso', icon: LogIn },
  { id: 'users', label: 'Usuarios', icon: ShieldCheck },
  { id: 'requests', label: 'Solicitudes', icon: ClipboardList },
  { id: 'approval', label: 'Aprobacion', icon: CheckCircle2 },
  { id: 'dashboard', label: 'Dashboard', icon: BarChart3 },
  { id: 'reset', label: 'Reset', icon: KeyRound },
];

const priorityOptions = ['BAJA', 'MEDIA', 'ALTA', 'URGENTE'];
const statusOptions = ['', 'BORRADOR', 'PENDIENTE', 'APROBADA', 'RECHAZADA', 'DEVUELTA', 'CANCELADA'];

function App() {
  const [activeView, setActiveView] = useState('auth');
  const [session, setSession] = useState(null);
  const [selectedSolicitud, setSelectedSolicitud] = useState('');
  const [toast, setToast] = useState('');
  const isAdmin = session?.role
    ?.split(',')
    .map((role) => role.trim())
    .includes('ADMIN');

  const visibleViews = useMemo(() => {
    if (!session) return views.filter((view) => ['auth', 'reset'].includes(view.id));
    return views.filter((view) => {
      if (view.id === 'requests') return !isAdmin;
      if (['users', 'approval'].includes(view.id)) return isAdmin;
      return true;
    });
  }, [isAdmin, session]);

  const notify = useCallback((message) => {
    setToast(message);
    window.clearTimeout(window.__sigescomToast);
    window.__sigescomToast = window.setTimeout(() => setToast(''), 4500);
  }, []);

  const content = {
    auth: <AuthView session={session} setSession={setSession} notify={notify} />,
    users: <UsersView session={session} notify={notify} />,
    requests: (
      <RequestsView
        session={session}
        isAdmin={isAdmin}
        notify={notify}
        selectedSolicitud={selectedSolicitud}
        setSelectedSolicitud={setSelectedSolicitud}
      />
    ),
    approval: <ApprovalView session={session} notify={notify} setSelectedSolicitud={setSelectedSolicitud} />,
    dashboard: <DashboardView session={session} isAdmin={isAdmin} />,
    reset: <ResetView notify={notify} />,
  }[activeView];

  useEffect(() => {
    if (!visibleViews.some((view) => view.id === activeView)) {
      setActiveView(session ? 'requests' : 'auth');
    }
  }, [activeView, session, visibleViews]);

  return (
    <div className="min-h-screen bg-panel text-ink">
      <div className="flex min-h-screen">
        <aside className="hidden w-72 shrink-0 border-r border-line bg-white p-5 lg:block">
          <div className="mb-8">
            <p className="text-xs font-semibold uppercase tracking-wide text-brand">SIGESCOM</p>
            <h1 className="mt-1 text-2xl font-semibold">Gestion de compras</h1>
            <p className="mt-2 text-sm text-muted">Frontend React conectado a Oracle ORDS.</p>
          </div>
          <nav className="space-y-1">
            {visibleViews.map((view) => {
              const Icon = view.icon;
              const active = activeView === view.id;
              return (
                <button
                  key={view.id}
                  className={`nav-button ${active ? 'nav-button-active' : ''}`}
                  onClick={() => setActiveView(view.id)}
                >
                  <Icon size={18} />
                  <span>{view.label}</span>
                </button>
              );
            })}
          </nav>
          <SessionCard session={session} />
        </aside>

        <main className="flex-1">
          <header className="sticky top-0 z-20 border-b border-line bg-white/95 px-4 py-3 backdrop-blur md:px-8">
            <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
              <div>
                <p className="text-xs text-muted">Base ORDS</p>
                <p className="break-all text-sm font-medium">{API_BASE_URL}</p>
              </div>
              <div className="flex gap-2 overflow-x-auto lg:hidden">
                {visibleViews.map((view) => (
                  <button
                    key={view.id}
                    className={`mobile-tab ${activeView === view.id ? 'mobile-tab-active' : ''}`}
                    onClick={() => setActiveView(view.id)}
                  >
                    {view.label}
                  </button>
                ))}
              </div>
            </div>
          </header>

          <div className="p-4 md:p-8">{content}</div>
        </main>
      </div>
      {toast && <div className="toast">{toast}</div>}
    </div>
  );
}

function SessionCard({ session }) {
  if (!session) {
    return (
      <div className="mt-8 rounded-md border border-line bg-panel p-4">
        <p className="text-xs font-semibold uppercase tracking-wide text-muted">Sesion</p>
        <p className="mt-2 font-semibold">Sin sesion iniciada</p>
        <p className="mt-1 text-sm text-muted">Inicia sesion para cargar un usuario.</p>
      </div>
    );
  }

  return (
    <div className="mt-8 rounded-md border border-line bg-panel p-4">
      <p className="text-xs font-semibold uppercase tracking-wide text-muted">Sesion actual</p>
      <p className="mt-2 font-semibold">{session.name}</p>
      <p className="text-sm text-muted">ID {session.id}</p>
      <div className="mt-3 flex flex-wrap gap-2 text-xs">
        <span className="badge">{session.role}</span>
        <span className="badge">{session.department}</span>
      </div>
    </div>
  );
}

function Section({ title, description, children, actions }) {
  return (
    <section className="mb-6">
      <div className="mb-4 flex flex-col gap-3 md:flex-row md:items-end md:justify-between">
        <div>
          <h2 className="text-2xl font-semibold">{title}</h2>
          {description && <p className="mt-1 max-w-3xl text-sm text-muted">{description}</p>}
        </div>
        {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
      </div>
      {children}
    </section>
  );
}

function Panel({ title, children, className = '' }) {
  return (
    <div className={`rounded-md border border-line bg-white p-4 shadow-soft ${className}`}>
      {title && <h3 className="mb-4 text-base font-semibold">{title}</h3>}
      {children}
    </div>
  );
}

function Field({ label, children }) {
  return (
    <label className="block">
      <span className="mb-1 block text-sm font-medium">{label}</span>
      {children}
    </label>
  );
}

function Input(props) {
  return <input {...props} className={`input ${props.className || ''}`} />;
}

function Textarea(props) {
  return <textarea {...props} className={`input min-h-24 resize-y ${props.className || ''}`} />;
}

function Select({ children, ...props }) {
  return (
    <select {...props} className={`input ${props.className || ''}`}>
      {children}
    </select>
  );
}

function Button({ children, icon: Icon, variant = 'primary', loading = false, ...props }) {
  return (
    <button {...props} className={`btn btn-${variant} ${props.className || ''}`} disabled={loading || props.disabled}>
      {Icon && <Icon size={17} />}
      <span>{loading ? 'Procesando...' : children}</span>
    </button>
  );
}

function Alert({ type = 'info', children }) {
  if (!children) return null;
  return <div className={`alert alert-${type}`}>{children}</div>;
}

function AuthView({ session, setSession, notify }) {
  const departamentos = useAsync(catalogosApi.departamentos);
  const login = useForm({ correo: '', password_hash: '' });
  const register = useForm({
    nombre_completo: '',
    correo: '',
    password_hash: '',
    id_departamento: '',
    telefono: '',
    puesto: '',
  });
  const [result, setResult] = useState('');
  const [loading, setLoading] = useState(false);

  async function handleLogin(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const data = await authApi.login(login.values);
      const user = data.usuario || {};
      setSession({
        id: user.id || '',
        name: user.nombre || '',
        role: user.rol || '',
        department: user.departamento || '',
      });
      setResult(JSON.stringify(data, null, 2));
      login.reset({ correo: '', password_hash: '' });
      notify('Login correcto');
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function handleRegister(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const data = await authApi.registrar({ ...register.values, id_departamento: Number(register.values.id_departamento) });
      setResult(JSON.stringify(data, null, 2));
      notify('Usuario registrado');
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function handleValidateEmail() {
    setLoading(true);
    try {
      const data = await authApi.validarCorreo(register.values.correo);
      setResult(JSON.stringify(data, null, 2));
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function handleLogout() {
    try {
      if (session?.id) {
        await authApi.logout(session.id);
      }
      setSession(null);
      login.reset({ correo: '', password_hash: '' });
      register.reset({
        nombre_completo: '',
        correo: '',
        password_hash: '',
        id_departamento: '',
        telefono: '',
        puesto: '',
      });
      setResult('');
      notify('Logout registrado');
    } catch (error) {
      setResult(getErrorMessage(error));
    }
  }

  return (
    <Section title="Acceso y usuarios" description="Registro, login, validacion de correo y cierre de sesion.">
      <div className="grid gap-4 xl:grid-cols-[1fr_1fr_0.9fr]">
        <Panel title="Login">
          <form className="space-y-3" onSubmit={handleLogin}>
            <Field label="Correo">
              <Input type="email" placeholder="usuario@empresa.com" {...login.bind('correo')} />
            </Field>
            <Field label="Password hash">
              <Input placeholder="HASH_DE_LA_CONTRASENA" {...login.bind('password_hash')} />
            </Field>
            <Button icon={LogIn} loading={loading}>Iniciar sesion</Button>
          </form>
        </Panel>

        <Panel title="Registro">
          <form className="space-y-3" onSubmit={handleRegister}>
            <Field label="Nombre completo">
              <Input placeholder="Nombre y apellidos" {...register.bind('nombre_completo')} />
            </Field>
            <Field label="Correo">
              <div className="flex gap-2">
                <Input type="email" placeholder="usuario@empresa.com" {...register.bind('correo')} />
                <Button type="button" variant="secondary" icon={Search} onClick={handleValidateEmail} />
              </div>
            </Field>
            <Field label="Password hash">
              <Input placeholder="HASH_SIMULADO_001" {...register.bind('password_hash')} />
            </Field>
            <div className="grid gap-3 md:grid-cols-2">
              <Field label="Departamento">
                <Select {...register.bind('id_departamento')}>
                  {(departamentos.data || []).map((dep) => (
                    <option key={dep.id_departamento} value={dep.id_departamento}>
                      {dep.nombre}
                    </option>
                  ))}
                </Select>
              </Field>
              <Field label="Telefono">
                <Input placeholder="8888-0000" {...register.bind('telefono')} />
              </Field>
            </div>
            <Field label="Puesto">
              <Input placeholder="Analista de compras" {...register.bind('puesto')} />
            </Field>
            <Button icon={UserPlus} loading={loading}>Registrar</Button>
          </form>
        </Panel>

        <Panel title="Resultado">
          <SessionCard session={session} />
          <div className="mt-4 flex gap-2">
            <Button icon={LogOut} variant="secondary" onClick={handleLogout}>Logout</Button>
          </div>
          <pre className="result">{result || 'Las respuestas del API apareceran aqui.'}</pre>
        </Panel>
      </div>
    </Section>
  );
}

function ResetView({ notify }) {
  const form = useForm({
    correo: '',
    codigo_reset: '',
    password_hash: '',
  });
  const [result, setResult] = useState('');
  const [loading, setLoading] = useState(false);

  async function run(action) {
    setLoading(true);
    try {
      let data;
      if (action === 'request') {
        data = await authApi.solicitarReset({
          correo: form.values.correo,
          ip_solicitud: 'frontend',
          user_agent: navigator.userAgent.slice(0, 300),
        });
        if (data.codigo_reset) form.update('codigo_reset', data.codigo_reset);
      }
      if (action === 'validate') data = await authApi.validarReset(form.values.codigo_reset);
      if (action === 'change') data = await authApi.cambiarPassword(form.values);
      setResult(JSON.stringify(data, null, 2));
      notify('Operacion de reset completada');
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Section title="Recuperacion de contrasena" description="Genera, valida y consume codigos reset.">
      <div className="grid gap-4 lg:grid-cols-[1fr_1fr]">
        <Panel title="Flujo reset">
          <div className="grid gap-3 md:grid-cols-2">
            <Field label="Correo">
              <Input type="email" placeholder="usuario@empresa.com" {...form.bind('correo')} />
            </Field>
            <Field label="Nuevo password hash">
              <Input placeholder="HASH_NUEVO_001" {...form.bind('password_hash')} />
            </Field>
          </div>
          <Field label="Codigo reset">
            <Input placeholder="Codigo generado por el sistema" {...form.bind('codigo_reset')} />
          </Field>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button icon={KeyRound} loading={loading} onClick={() => run('request')}>Generar codigo</Button>
            <Button icon={Search} variant="secondary" loading={loading} onClick={() => run('validate')}>Validar codigo</Button>
            <Button icon={Save} variant="secondary" loading={loading} onClick={() => run('change')}>Cambiar password</Button>
          </div>
        </Panel>
        <Panel title="Respuesta">
          <pre className="result">{result || 'Ejecuta una accion para ver la respuesta.'}</pre>
        </Panel>
      </div>
    </Section>
  );
}

function UsersView({ session, notify }) {
  const filters = useForm({ estado: 'PENDIENTE_ACTIVACION', correo: '' });
  const admin = useForm({ id_admin: session?.id || '', estado: 'ACTIVO' });
  const [users, setUsers] = useState([]);
  const [selected, setSelected] = useState('');
  const [result, setResult] = useState('');
  const [loading, setLoading] = useState(false);

  async function loadPending() {
    setLoading(true);
    setResult('');
    try {
      const data = await usuariosApi.pendientes();
      setUsers(data);
      setResult(`Usuarios pendientes encontrados: ${data.length}`);
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function loadFiltered() {
    setLoading(true);
    setResult('');
    try {
      const clean = Object.fromEntries(Object.entries(filters.values).filter(([, value]) => value !== ''));
      const data = await usuariosApi.listar(clean);
      setUsers(data);
      setResult(`Usuarios encontrados: ${data.length}`);
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function changeStatus() {
    if (!selected) {
      setResult('Selecciona un usuario primero.');
      return;
    }
    setLoading(true);
    try {
      const data = await usuariosApi.cambiarEstado(selected, {
        id_admin: Number(admin.values.id_admin),
        estado: admin.values.estado,
      });
      setResult(JSON.stringify(data, null, 2));
      notify('Estado de usuario actualizado');
      await loadFiltered();
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  return (
    <Section title="Usuarios" description="Activa cuentas pendientes desde el frontend. Usa un usuario con rol ADMIN.">
      <div className="grid gap-4 xl:grid-cols-[1fr_0.8fr]">
        <Panel title="Consulta">
          <div className="grid gap-3 md:grid-cols-3">
            <Field label="Estado">
              <Select {...filters.bind('estado')}>
                <option value="">Todos</option>
                <option>PENDIENTE_ACTIVACION</option>
                <option>ACTIVO</option>
                <option>INACTIVO</option>
                <option>BLOQUEADO</option>
              </Select>
            </Field>
            <Field label="Correo">
              <Input placeholder="Filtrar por correo" {...filters.bind('correo')} />
            </Field>
            <div className="flex items-end gap-2">
              <Button icon={RefreshCcw} variant="secondary" loading={loading} onClick={loadPending}>Pendientes</Button>
              <Button icon={Search} loading={loading} onClick={loadFiltered}>Buscar</Button>
            </div>
          </div>
          <UsersTable rows={users} selected={selected} onSelect={setSelected} />
        </Panel>

        <Panel title="Cambiar estado">
          <div className="grid gap-3 md:grid-cols-2">
            <Field label="ID admin">
              <Input type="number" placeholder="ID del usuario ADMIN" {...admin.bind('id_admin')} />
            </Field>
            <Field label="Nuevo estado">
              <Select {...admin.bind('estado')}>
                <option>ACTIVO</option>
                <option>INACTIVO</option>
                <option>BLOQUEADO</option>
              </Select>
            </Field>
          </div>
          <Field label="Usuario seleccionado">
            <Input placeholder="ID del usuario a actualizar" value={selected} onChange={(event) => setSelected(event.target.value)} />
          </Field>
          <div className="mt-4">
            <Button icon={ShieldCheck} loading={loading} onClick={changeStatus}>Actualizar estado</Button>
          </div>
          <pre className="result">{result || 'Selecciona un usuario pendiente y cambia su estado a ACTIVO.'}</pre>
        </Panel>
      </div>
    </Section>
  );
}

function RequestsView({ session, isAdmin, notify, selectedSolicitud, setSelectedSolicitud }) {
  const defaultItem = { tipo_item: 'PRODUCTO', descripcion: '', cantidad: '', precio_estimado: '', proveedor_sugerido: '' };
  const form = useForm({
    id_usuario_solicitante: '',
    prioridad: 'ALTA',
    justificacion: '',
    observaciones: '',
  });
  const filters = useForm({ estado: '', departamento: '', prioridad: '', montoMin: '', montoMax: '' });
  const [items, setItems] = useState([defaultItem]);
  const [requests, setRequests] = useState([]);
  const [detail, setDetail] = useState([]);
  const [result, setResult] = useState('');
  const [loading, setLoading] = useState(false);

  function updateItem(index, field, value) {
    setItems((current) => current.map((item, itemIndex) => (itemIndex === index ? { ...item, [field]: value } : item)));
  }

  async function createRequest(event) {
    event.preventDefault();
    setLoading(true);
    try {
      const payload = {
        ...form.values,
        id_usuario_solicitante: Number(isAdmin ? form.values.id_usuario_solicitante : session?.id),
        items_json: JSON.stringify(items.map((item) => ({
          ...item,
          cantidad: Number(item.cantidad),
          precio_estimado: Number(item.precio_estimado),
        }))),
      };
      const data = await solicitudesApi.crear(payload);
      if (data.id_solicitud) setSelectedSolicitud(String(data.id_solicitud));
      setResult(JSON.stringify(data, null, 2));
      notify('Solicitud creada');
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function loadMine() {
    const idUsuario = isAdmin ? form.values.id_usuario_solicitante : session?.id;
    if (!idUsuario) {
      setResult('No hay usuario en sesion para consultar solicitudes.');
      return;
    }
    setRequests(await solicitudesApi.misSolicitudes(idUsuario));
  }

  async function loadFiltered() {
    const clean = Object.fromEntries(Object.entries(filters.values).filter(([, value]) => value !== ''));

    if (isAdmin) {
      setRequests(await solicitudesApi.listar(clean));
      return;
    }

    if (!session?.id) {
      setResult('No hay usuario en sesion para filtrar solicitudes.');
      return;
    }

    const ownRows = await solicitudesApi.misSolicitudes(session.id);
    const filteredRows = ownRows.filter((row) => {
      const byEstado = !clean.estado || row.estado === clean.estado;
      const byPrioridad = !clean.prioridad || row.prioridad === clean.prioridad;
      const byMontoMin = !clean.montoMin || Number(row.total || 0) >= Number(clean.montoMin);
      const byMontoMax = !clean.montoMax || Number(row.total || 0) <= Number(clean.montoMax);
      return byEstado && byPrioridad && byMontoMin && byMontoMax;
    });
    setRequests(filteredRows);
  }

  async function loadDetail(id = selectedSolicitud) {
    if (!id) return;
    const rows = await solicitudesApi.detalle(id);
    setDetail(rows);
    setSelectedSolicitud(String(id));
  }

  async function sendRequest() {
    setLoading(true);
    try {
      const data = await solicitudesApi.enviar(
        selectedSolicitud,
        Number(isAdmin ? form.values.id_usuario_solicitante : session?.id),
      );
      setResult(JSON.stringify(data, null, 2));
      notify('Solicitud enviada');
      await loadDetail();
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  async function deleteDraft() {
    setLoading(true);
    try {
      const data = await solicitudesApi.eliminar(
        selectedSolicitud,
        Number(isAdmin ? form.values.id_usuario_solicitante : session?.id),
      );
      setResult(JSON.stringify(data, null, 2));
      setDetail([]);
      notify('Borrador eliminado');
    } catch (error) {
      setResult(getErrorMessage(error));
    } finally {
      setLoading(false);
    }
  }

  const header = detail[0] || {};
  const detailTotal = useMemo(() => detail.reduce((sum, row) => sum + Number(row.subtotal_linea || 0), 0), [detail]);

  return (
    <Section title="Solicitudes de compra" description="Crea solicitudes con detalle, consulta filtros, envia a aprobacion y elimina borradores.">
      <div className="grid gap-4 2xl:grid-cols-[1.05fr_1fr]">
        <Panel title="Crear solicitud">
          <form className="space-y-3" onSubmit={createRequest}>
            <div className="grid gap-3 md:grid-cols-2">
              {isAdmin ? (
                <Field label="Usuario solicitante">
                  <Input type="number" placeholder="ID del usuario solicitante" {...form.bind('id_usuario_solicitante')} />
                </Field>
              ) : (
                <Field label="Usuario solicitante">
                  <Input value={session?.name ? `${session.name} (ID ${session.id})` : 'Sesion requerida'} disabled />
                </Field>
              )}
              <Field label="Prioridad">
                <Select {...form.bind('prioridad')}>
                  {priorityOptions.map((priority) => <option key={priority}>{priority}</option>)}
                </Select>
              </Field>
            </div>
            <Field label="Justificacion">
              <Textarea placeholder="Explique por que se necesita esta compra" {...form.bind('justificacion')} />
            </Field>
            <Field label="Observaciones">
              <Textarea placeholder="Notas adicionales opcionales" {...form.bind('observaciones')} />
            </Field>
            <div className="space-y-3">
              {items.map((item, index) => (
                <div key={index} className="rounded-md border border-line bg-panel p-3">
                  <div className="grid gap-3 md:grid-cols-[0.7fr_1.2fr_0.5fr_0.7fr]">
                    <Select value={item.tipo_item} onChange={(event) => updateItem(index, 'tipo_item', event.target.value)}>
                      <option>PRODUCTO</option>
                      <option>SERVICIO</option>
                    </Select>
                    <Input placeholder="Descripcion del item" value={item.descripcion} onChange={(event) => updateItem(index, 'descripcion', event.target.value)} />
                    <Input type="number" placeholder="Cantidad" value={item.cantidad} onChange={(event) => updateItem(index, 'cantidad', event.target.value)} />
                    <Input type="number" placeholder="Precio estimado" value={item.precio_estimado} onChange={(event) => updateItem(index, 'precio_estimado', event.target.value)} />
                  </div>
                  <Input className="mt-3" placeholder="Proveedor sugerido opcional" value={item.proveedor_sugerido} onChange={(event) => updateItem(index, 'proveedor_sugerido', event.target.value)} />
                </div>
              ))}
            </div>
            <div className="flex flex-wrap gap-2">
              <Button icon={Save} loading={loading}>Crear solicitud</Button>
              <Button type="button" variant="secondary" onClick={() => setItems((current) => [...current, defaultItem])}>Agregar item</Button>
            </div>
          </form>
        </Panel>

        <Panel title="Consultar y operar">
          <div className="grid gap-3 md:grid-cols-3">
            <Field label="Estado">
              <Select {...filters.bind('estado')}>
                {statusOptions.map((status) => <option key={status} value={status}>{status || 'Todos'}</option>)}
              </Select>
            </Field>
            <Field label="Departamento">
              <Input placeholder="ID departamento, por ejemplo 1" {...filters.bind('departamento')} />
            </Field>
            <Field label="Prioridad">
              <Select {...filters.bind('prioridad')}>
                <option value="">Todas</option>
                {priorityOptions.map((priority) => <option key={priority}>{priority}</option>)}
              </Select>
            </Field>
            <Field label="Monto min">
              <Input type="number" placeholder="0" {...filters.bind('montoMin')} />
            </Field>
            <Field label="Monto max">
              <Input type="number" placeholder="1000000" {...filters.bind('montoMax')} />
            </Field>
            <Field label="ID seleccionado">
              <Input placeholder="ID de solicitud" value={selectedSolicitud} onChange={(event) => setSelectedSolicitud(event.target.value)} />
            </Field>
          </div>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button icon={RefreshCcw} variant="secondary" onClick={loadMine}>Mis solicitudes</Button>
            <Button icon={Search} variant="secondary" onClick={loadFiltered}>Filtrar</Button>
            <Button icon={ClipboardList} variant="secondary" onClick={() => loadDetail()}>Ver detalle</Button>
            <Button icon={Send} onClick={sendRequest} loading={loading}>Enviar</Button>
            <Button icon={Trash2} variant="danger" onClick={deleteDraft} loading={loading}>Eliminar</Button>
          </div>
          <RequestsTable rows={requests} onSelect={(id) => loadDetail(id)} />
        </Panel>
      </div>

      <div className="mt-4 grid gap-4 xl:grid-cols-[1fr_0.7fr]">
        <Panel title="Detalle seleccionado">
          {detail.length ? (
            <>
              <div className="mb-4 grid gap-3 md:grid-cols-4">
                <Metric label="Solicitud" value={header.numero_solicitud || header.id_solicitud} />
                <Metric label="Estado" value={header.estado} />
                <Metric label="Total" value={currency(header.total)} />
                <Metric label="Items" value={detail.length} />
              </div>
              <DataTable
                columns={[
                  ['tipo_item', 'Tipo'],
                  ['descripcion', 'Descripcion'],
                  ['cantidad', 'Cantidad'],
                  ['precio_estimado', 'Precio'],
                  ['subtotal_linea', 'Subtotal'],
                ]}
                rows={detail}
                formatters={{ precio_estimado: currency, subtotal_linea: currency }}
              />
              <p className="mt-3 text-right text-sm font-semibold">Subtotal de lineas: {currency(detailTotal)}</p>
            </>
          ) : (
            <Alert>Selecciona una solicitud para ver su detalle.</Alert>
          )}
        </Panel>
        <Panel title="Respuesta API">
          <pre className="result">{result || 'Las respuestas de crear, enviar o eliminar apareceran aqui.'}</pre>
        </Panel>
      </div>
    </Section>
  );
}

function ApprovalView({ session, notify, setSelectedSolicitud }) {
  const [rows, setRows] = useState([]);
  const [history, setHistory] = useState([]);
  const [selected, setSelected] = useState('');
  const form = useForm({ observacion: '' });
  const [result, setResult] = useState('');

  const loadPending = useCallback(async () => {
    if (!session?.id) return;
    setResult('');
    try {
      const data = await solicitudesApi.pendientes(session.id);
      setRows(data);
      setResult(`Solicitudes pendientes encontradas: ${data.length}`);
    } catch (error) {
      setRows([]);
      setResult(getErrorMessage(error));
    }
  }, [session?.id]);

  useEffect(() => {
    loadPending();
  }, [loadPending]);

  async function decide(action) {
    try {
      const id = selected;
      const payload = { id_usuario_accion: Number(session?.id), observacion: form.values.observacion };
      const data = await solicitudesApi[action](id, payload);
      const detail = await solicitudesApi.detalle(id);
      const currentState = detail[0]?.estado || 'ACTUALIZADA';
      setRows((current) => current.filter((row) => String(row.id || row.id_solicitud) !== String(id)));
      setResult(JSON.stringify({ ...data, estado_actual: currentState }, null, 2));
      notify(`Solicitud ${action}`);
      await loadPending();
      await loadHistory(id);
      setSelected('');
    } catch (error) {
      setResult(getErrorMessage(error));
    }
  }

  async function loadHistory(id = selected) {
    if (!id) return;
    setHistory(await solicitudesApi.historial(id));
    setSelectedSolicitud(String(id));
  }

  return (
    <Section title="Aprobacion" description="Consulta pendientes y aplica decisiones con observacion obligatoria.">
      <div className="grid gap-4 xl:grid-cols-[1fr_0.9fr]">
        <Panel title="Pendientes">
          <div className="grid gap-3 md:grid-cols-3">
            <Field label="ID aprobador">
              <Input value={session?.id || ''} disabled />
            </Field>
            <Field label="ID solicitud">
              <Input placeholder="ID de solicitud pendiente" value={selected} onChange={(event) => setSelected(event.target.value)} />
            </Field>
            <div className="flex items-end">
              <Button icon={RefreshCcw} variant="secondary" onClick={loadPending}>Cargar pendientes</Button>
            </div>
          </div>
          <RequestsTable
            rows={rows}
            onSelect={(id) => {
              setSelected(String(id));
              loadHistory(id);
            }}
          />
        </Panel>

        <Panel title="Decision">
          <Field label="Observacion">
            <Textarea placeholder="Explique la decision tomada sobre la solicitud" {...form.bind('observacion')} />
          </Field>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button icon={CheckCircle2} onClick={() => decide('aprobar')} disabled={!selected}>Aprobar</Button>
            <Button icon={Trash2} variant="danger" onClick={() => decide('rechazar')} disabled={!selected}>Rechazar</Button>
            <Button icon={Send} variant="secondary" onClick={() => decide('devolver')} disabled={!selected}>Devolver</Button>
            <Button icon={ClipboardList} variant="secondary" onClick={() => loadHistory()} disabled={!selected}>Historial</Button>
          </div>
          <pre className="result">{result || 'Selecciona una solicitud pendiente.'}</pre>
        </Panel>
      </div>

      <Panel title="Historial" className="mt-4">
        <DataTable
          rows={history}
          columns={[
            ['fecha_accion', 'Fecha'],
            ['usuario_accion', 'Usuario'],
            ['estado_anterior', 'Anterior'],
            ['estado_nuevo', 'Nuevo'],
            ['observacion', 'Observacion'],
          ]}
          formatters={{ fecha_accion: dateTime }}
        />
      </Panel>
    </Section>
  );
}

function DashboardView({ session, isAdmin }) {
  const resumen = useAsync(dashboardApi.resumen, { immediate: false });
  const [all, setAll] = useState([]);

  async function load() {
    if (isAdmin) {
      await resumen.run();
      setAll(await solicitudesApi.listar());
      return;
    }

    if (!session?.id) {
      resumen.setData({
        total_solicitudes: 0,
        aprobadas: 0,
        rechazadas: 0,
        pendientes: 0,
        monto_total_solicitado: 0,
      });
      setAll([]);
      return;
    }

    const rows = await solicitudesApi.misSolicitudes(session.id);
    setAll(rows);
    resumen.setData({
      total_solicitudes: rows.length,
      aprobadas: rows.filter((row) => row.estado === 'APROBADA').length,
      rechazadas: rows.filter((row) => row.estado === 'RECHAZADA').length,
      pendientes: rows.filter((row) => row.estado === 'PENDIENTE').length,
      monto_total_solicitado: rows.reduce((sum, row) => sum + Number(row.total || 0), 0),
    });
  }

  return (
    <Section
      title="Dashboard"
      description={isAdmin ? 'Indicadores generales y listado completo de solicitudes.' : 'Indicadores y solicitudes del usuario en sesion.'}
      actions={<Button icon={RefreshCcw} onClick={load} loading={resumen.loading}>Actualizar</Button>}
    >
      <div className="grid gap-4 md:grid-cols-5">
        <Metric label="Total" value={resumen.data?.total_solicitudes ?? 0} />
        <Metric label="Aprobadas" value={resumen.data?.aprobadas ?? 0} />
        <Metric label="Rechazadas" value={resumen.data?.rechazadas ?? 0} />
        <Metric label="Pendientes" value={resumen.data?.pendientes ?? 0} />
        <Metric label="Monto" value={currency(resumen.data?.monto_total_solicitado)} />
      </div>
      <Panel title="Solicitudes" className="mt-4">
        <RequestsTable rows={all} />
      </Panel>
    </Section>
  );
}

function UsersTable({ rows, selected, onSelect }) {
  return (
    <div className="mt-4 overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Nombre</th>
            <th>Correo</th>
            <th>Departamento</th>
            <th>Puesto</th>
            <th>Estado</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td colSpan="7" className="empty-cell">Sin usuarios cargados</td>
            </tr>
          ) : (
            rows.map((row) => (
              <tr key={row.id_usuario} className={String(row.id_usuario) === String(selected) ? 'bg-teal-50' : ''}>
                <td>{row.id_usuario}</td>
                <td>{row.nombre_completo}</td>
                <td>{row.correo}</td>
                <td>{row.departamento}</td>
                <td>{row.puesto}</td>
                <td><span className="status">{row.estado}</span></td>
                <td>
                  <button className="link-button" onClick={() => onSelect(String(row.id_usuario))}>Seleccionar</button>
                </td>
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

function RequestsTable({ rows, onSelect }) {
  return (
    <div className="mt-4 overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Numero</th>
            <th>Solicitante</th>
            <th>Estado</th>
            <th>Prioridad</th>
            <th>Total</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td colSpan="7" className="empty-cell">Sin datos cargados</td>
            </tr>
          ) : (
            rows.map((row) => {
              const id = row.id || row.id_solicitud;
              return (
                <tr key={`${id}-${row.numero_solicitud || ''}`}>
                  <td>{id}</td>
                  <td>{row.numero_solicitud || '-'}</td>
                  <td>{row.solicitante || '-'}</td>
                  <td><span className="status">{row.estado}</span></td>
                  <td>{row.prioridad || '-'}</td>
                  <td>{currency(row.total)}</td>
                  <td>
                    {onSelect && (
                      <button className="link-button" onClick={() => onSelect(id)}>Abrir</button>
                    )}
                  </td>
                </tr>
              );
            })
          )}
        </tbody>
      </table>
    </div>
  );
}

function DataTable({ rows, columns, formatters = {} }) {
  return (
    <div className="overflow-x-auto">
      <table className="data-table">
        <thead>
          <tr>
            {columns.map(([, label]) => <th key={label}>{label}</th>)}
          </tr>
        </thead>
        <tbody>
          {rows.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="empty-cell">Sin datos</td>
            </tr>
          ) : (
            rows.map((row, index) => (
              <tr key={index}>
                {columns.map(([key]) => (
                  <td key={key}>{formatters[key] ? formatters[key](row[key]) : row[key] || '-'}</td>
                ))}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

function Metric({ label, value }) {
  return (
    <div className="rounded-md border border-line bg-white p-4 shadow-soft">
      <p className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</p>
      <p className="mt-2 break-all text-xl font-semibold leading-snug">{value}</p>
    </div>
  );
}

export default App;
