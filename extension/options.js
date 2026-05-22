window.createTabGroup = async function (urls, groupName, color) {
  const tabIds = [];
  for (const url of urls) {
    const tab = await chrome.tabs.create({ url, active: false });
    tabIds.push(tab.id);
  }
  const groupId = await chrome.tabs.group({ tabIds });
  if (chrome.tabGroups) {
    await chrome.tabGroups.update(groupId, { title: groupName, color: color || 'cyan' });
  }
  return { groupId, tabIds, groupName };
};

window.createAllGroups = async function (groups) {
  const results = [];
  for (const g of groups) {
    try {
      const r = await window.createTabGroup(
        g.tabs.map(t => t.url),
        g.name,
        g.edgeColor || 'cyan'
      );
      results.push({ name: g.name, ok: true, groupId: r.groupId, count: r.tabIds.length });
    } catch (e) {
      results.push({ name: g.name, ok: false, error: e.message });
    }
  }
  return results;
};
