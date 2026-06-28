import { useState } from 'react';

export function useForm(initialValues) {
  const [values, setValues] = useState(initialValues);

  function update(field, value) {
    setValues((current) => ({ ...current, [field]: value }));
  }

  function bind(field) {
    return {
      value: values[field] ?? '',
      onChange: (event) => update(field, event.target.value),
    };
  }

  function reset(nextValues = initialValues) {
    setValues(nextValues);
  }

  return { values, setValues, update, bind, reset };
}

