import { useCallback, useEffect, useState } from 'react';
import { getErrorMessage } from '../api/client';

export function useAsync(asyncFn, { immediate = true } = {}) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const run = useCallback(
    async (...args) => {
      setLoading(true);
      setError('');
      try {
        const result = await asyncFn(...args);
        setData(result);
        return result;
      } catch (err) {
        const message = getErrorMessage(err);
        setError(message);
        throw err;
      } finally {
        setLoading(false);
      }
    },
    [asyncFn],
  );

  useEffect(() => {
    if (immediate) run();
  }, [immediate, run]);

  return { data, setData, loading, error, setError, run };
}

