/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#1f2933',
        muted: '#6b7280',
        line: '#d9dee7',
        panel: '#f7f9fc',
        brand: '#0f766e',
        accent: '#9a3412',
      },
      boxShadow: {
        soft: '0 10px 28px rgba(15, 23, 42, 0.08)',
      },
    },
  },
  plugins: [],
};

