document.addEventListener('DOMContentLoaded', () => {
    // 이벤트 위임(Event Delegation)을 사용하여 동적으로 생성된 요소도 처리 가능하게 함
    document.addEventListener('click', (e) => {
        // 클릭된 요소가 .tab[data-tab] 인지 확인 (혹은 그 내부 요소인지)
        const tab = e.target.closest('.tabs[data-view-container] .tab[data-tab]');
        if (!tab) return;

        e.preventDefault();

        const tabsContainer = tab.closest('.tabs[data-view-container]');
        const viewContainerId = tabsContainer.getAttribute('data-view-container');
        const viewsContainer = document.getElementById(viewContainerId);
        const tabName = tab.getAttribute('data-tab');

        if (!viewsContainer) return;

        // 탭 활성화 상태 변경
        tabsContainer.querySelectorAll('.tab').forEach(el => el.classList.remove('selected'));
        tab.classList.add('selected');

        // 뷰 활성화 상태 변경
        viewsContainer.querySelectorAll('.tab').forEach(el => el.classList.remove('selected'));
        const targetView = viewsContainer.querySelector(`.tab.${tabName}`);
        if (targetView) {
            targetView.classList.add('selected');
        }
    });
});