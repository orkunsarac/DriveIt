(() => {
  const button = document.getElementById('copy-email');
  const status = document.getElementById('copy-status');
  const address = document.getElementById('support-email')?.textContent?.trim();
  if (!button || !status || !address) return;

  button.addEventListener('click', async () => {
    try {
      if (navigator.clipboard && window.isSecureContext) {
        await navigator.clipboard.writeText(address);
      } else {
        const field = document.createElement('textarea');
        field.value = address;
        field.setAttribute('readonly', '');
        field.style.position = 'fixed';
        field.style.opacity = '0';
        document.body.append(field);
        field.select();
        const copied = document.execCommand('copy');
        field.remove();
        if (!copied) throw new Error('copy unavailable');
      }
      status.textContent = 'Adres kopyalandı.';
    } catch {
      status.textContent = 'Otomatik kopyalama kullanılamıyor. E-posta adresini seçip elle kopyalayın.';
    }
  });
})();
