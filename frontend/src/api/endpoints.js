import { api, getRows } from './client';

export const catalogosApi = {
  departamentos: async () => getRows((await api.get('/catalogos/departamentos')).data),
};

export const authApi = {
  validarCorreo: async (correo) => (await api.post('/auth/validar-correo', { correo })).data,
  registrar: async (payload) => (await api.post('/auth/register', payload)).data,
  login: async (payload) => (await api.post('/auth/login', payload)).data,
  perfil: async (idUsuario) => (await api.get('/auth/perfil', { params: { id_usuario: idUsuario } })).data,
  logout: async (idUsuario) => (await api.post('/auth/logout', { id_usuario: idUsuario })).data,
  solicitarReset: async (payload) => (await api.post('/auth/solicitar-reset', payload)).data,
  validarReset: async (codigo_reset) => (await api.post('/auth/validar-reset', { codigo_reset })).data,
  cambiarPassword: async (payload) => (await api.post('/auth/cambiar-password', payload)).data,
};

export const usuariosApi = {
  listar: async (params = {}) => getRows((await api.get('/usuarios/', { params })).data),
  pendientes: async () => getRows((await api.get('/usuarios/pendientes')).data),
  cambiarEstado: async (idUsuario, payload) => (await api.put(`/usuarios/${idUsuario}/estado`, payload)).data,
};

export const solicitudesApi = {
  crear: async (payload) => (await api.post('/solicitudes/', payload)).data,
  listar: async (params = {}) => getRows((await api.get('/solicitudes/', { params })).data),
  misSolicitudes: async (idUsuario) =>
    getRows((await api.get('/solicitudes/mis-solicitudes', { params: { id_usuario: idUsuario } })).data),
  pendientes: async (idUsuario) =>
    getRows((await api.get('/solicitudes/pendientes', { params: { id_usuario: idUsuario } })).data),
  detalle: async (id) => getRows((await api.get(`/solicitudes/${id}`)).data),
  enviar: async (id, idUsuario) => (await api.put(`/solicitudes/${id}/enviar`, { id_usuario: idUsuario })).data,
  aprobar: async (id, payload) => (await api.put(`/solicitudes/${id}/aprobar`, payload)).data,
  rechazar: async (id, payload) => (await api.put(`/solicitudes/${id}/rechazar`, payload)).data,
  devolver: async (id, payload) => (await api.put(`/solicitudes/${id}/devolver`, payload)).data,
  historial: async (id) => getRows((await api.get(`/solicitudes/${id}/historial`)).data),
  eliminar: async (id, idUsuario) => (await api.delete(`/solicitudes/${id}`, { data: { id_usuario: idUsuario } })).data,
};

export const dashboardApi = {
  resumen: async () => getRows((await api.get('/dashboard/resumen')).data)[0] || {},
};
